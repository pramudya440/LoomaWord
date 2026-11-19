import Foundation
import Combine
import AppKit
import os

@MainActor
public final class TranslationCoordinator: ObservableObject {
    public static let shared = TranslationCoordinator()

    // MARK: - Published State
    @Published public var sourceText: String = ""
    @Published public var translatedText: String = ""
    @Published public var sourceLang: String = "auto"
    @Published public var targetLang: String = "id"
    @Published public var selectedEngine: TranslationEngineType = .smart
    @Published public var selectedTone: TranslationTone = .standard
    @Published public var alternatives: [String] = []
    @Published public var isTranslating: Bool = false
    @Published public var statusMessage: String = ""
    @Published public var latencyMs: Double = 0
    @Published public var errorMessage: String? = nil

    /// Every change autosaves (debounced) so closing the app never loses an API key.
    @Published public var settings: AppSettings {
        didSet { scheduleSettingsSave() }
    }
    @Published public var glossary: [GlossaryItem] = []
    @Published public var history: [TranslationHistoryItem] = []

    private var translateTask: Task<Void, Never>?
    private let storage = StorageManager.shared
    private let logger = Logger(subsystem: "com.pramudya.loomaword", category: "translation")

    /// Monotonic token so only the newest request may touch UI state
    /// (fixes the spinner that could spin forever after a cancelled request).
    private var requestGeneration: Int = 0
    /// Text of the most recently started request — used to de-dupe the
    /// `onChange` path against explicit `triggerTranslation()` calls.
    private var lastRequestedText: String = ""

    private var settingsSaveWork: DispatchWorkItem?
    private var historySaveWork: DispatchWorkItem?
    private var historyLoaded = false

    // Translation cache (LRU): re-translating the same text is free.
    private var cache: [String: TranslationResult] = [:]
    private var cacheOrder: [String] = []
    private let cacheLimit = 100

    private init() {
        self.settings = storage.loadSettings()
        self.glossary = storage.loadGlossary()
        self.history = storage.loadHistory()
        self.historyLoaded = true

        self.selectedEngine = settings.preferredEngine
        self.selectedTone = settings.selectedTone
        self.sourceLang = settings.defaultSourceLang
        self.targetLang = settings.defaultTargetLang
    }

    // MARK: - Persistence

    /// Explicit save (syncs UI state into settings, then persists).
    public func saveSettings() {
        settings.preferredEngine = selectedEngine
        settings.selectedTone = selectedTone
        settings.defaultSourceLang = sourceLang
        settings.defaultTargetLang = targetLang
        // Direct assignment also triggers didSet, but persist immediately so a
        // subsequent quit doesn't race the debounce.
        persistSettingsNow()
    }

    private func scheduleSettingsSave() {
        settingsSaveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.persistSettingsNow()
            }
        }
        settingsSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func persistSettingsNow() {
        settingsSaveWork?.cancel()
        settingsSaveWork = nil
        storage.saveSettings(settings)
    }

    /// Write any debounced-but-pending changes immediately (called on app termination).
    public func flushPendingSaves() {
        persistSettingsNow()
        if let work = historySaveWork {
            work.cancel()
            historySaveWork = nil
            storage.saveHistory(history)
        }
    }

    public func saveGlossary() {
        storage.saveGlossary(glossary)
    }

    private func loadHistoryIfNeeded() {
        guard !historyLoaded else { return }
        historyLoaded = true
        history = storage.loadHistory()
    }

    private func scheduleHistorySave() {
        historySaveWork?.cancel()
        let snapshot = history
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.storage.saveHistory(snapshot)
            }
        }
        historySaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func addHistory(_ item: TranslationHistoryItem) {
        loadHistoryIfNeeded()
        // De-dupe: identical consecutive entry (e.g. cache miss after relaunch).
        if let first = history.first,
           first.sourceText == item.sourceText,
           first.targetLang == item.targetLang,
           first.sourceLang == item.sourceLang,
           Date().timeIntervalSince(first.timestamp) < 120 {
            return
        }
        history.insert(item, at: 0)
        if history.count > 200 {
            history = Array(history.prefix(200))
        }
        scheduleHistorySave()
    }

    public func clearHistory() {
        history = []
        historyLoaded = true
        historySaveWork?.cancel()
        storage.saveHistory([])
    }

    // MARK: - Translation Execution

    /// Entry point for user-initiated translations.
    /// - Parameter debounce: true for the as-you-type `onChange` path; that path is
    ///   de-duplicated against `lastRequestedText` so programmatic text changes that
    ///   also call `triggerTranslation()` don't fire two requests.
    public func triggerTranslation(debounce: Bool = false) {
        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            translateTask?.cancel()
            requestGeneration += 1
            lastRequestedText = ""
            isTranslating = false
            translatedText = ""
            alternatives = []
            statusMessage = ""
            errorMessage = nil
            return
        }

        // De-dupe the as-you-type path: an explicit trigger for the same text
        // (import, paste, tone change) already covers it.
        if debounce, text == lastRequestedText {
            return
        }

        translateTask?.cancel()
        requestGeneration += 1
        let generation = requestGeneration
        lastRequestedText = text

        translateTask = Task { [weak self] in
            guard let self else { return }

            if debounce {
                // 700ms: long enough to avoid billing a request per keystroke.
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            guard !Task.isCancelled else { return }

            self.isTranslating = true
            self.errorMessage = nil
            self.statusMessage = "Menerjemahkan..."
            defer {
                if generation == self.requestGeneration {
                    self.isTranslating = false
                }
            }

            do {
                let result = try await self.executeTranslation(text: text)
                guard !Task.isCancelled, generation == self.requestGeneration else { return }

                self.translatedText = result.translatedText
                self.alternatives = result.alternatives
                self.latencyMs = result.latencyMs
                self.statusMessage = "\(result.engine) • \(Int(result.latencyMs)) ms"
                if result.isCached {
                    self.statusMessage += " • cache"
                }

                if let detected = result.detectedSourceLang, self.sourceLang == "auto" {
                    let name = Language.find(code: detected)?.name ?? detected.uppercased()
                    self.statusMessage += " (\(name))"
                }

                if !result.isCached {
                    self.addHistory(TranslationHistoryItem(
                        sourceText: text,
                        translatedText: result.translatedText,
                        sourceLang: self.sourceLang,
                        targetLang: self.targetLang,
                        engineUsed: result.engine,
                        toneUsed: self.selectedTone.rawValue
                    ))
                }

                if self.settings.playSpeechAfterTranslation {
                    TTSManager.shared.speak(text: result.translatedText, langCode: self.targetLang)
                }
            } catch {
                guard !Task.isCancelled, generation == self.requestGeneration else { return }
                self.logger.error("Translation failed: \(error.localizedDescription, privacy: .public)")
                self.errorMessage = error.localizedDescription
                self.statusMessage = "Gagal menerjemahkan"
            }
        }
    }

    private func resolveEngine() -> TranslationEngineType {
        if selectedEngine == .smart {
            if !settings.deepLAuthKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .deepL
            } else if !settings.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || settings.aiProvider == .ollama {
                return .ai
            } else {
                return .fast
            }
        }
        return selectedEngine
    }

    private func executeTranslation(text: String) async throws -> TranslationResult {
        let engineToUse = resolveEngine()

        // Chunk large texts so we stay under provider request limits.
        let limit = engineToUse == .fast ? 1200 : 4000
        let chunks = TextChunker.chunk(text, maxChars: limit)

        if chunks.count > 1 {
            var parts: [String] = []
            var totalLatency = 0.0
            var engineName = ""
            for chunk in chunks {
                let piece = try await translateChunk(chunk, engine: engineToUse)
                parts.append(piece.translatedText)
                totalLatency += piece.latencyMs
                engineName = piece.engine
            }
            return TranslationResult(
                translatedText: parts.joined(separator: "\n\n"),
                engine: engineName,
                latencyMs: totalLatency
            )
        }

        return try await translateChunk(text, engine: engineToUse)
    }

    private func translateChunk(_ text: String, engine: TranslationEngineType) async throws -> TranslationResult {
        // Cache lookup (glossary participates in the key so edits invalidate it).
        let key = Self.cacheKey(
            text: text,
            source: sourceLang,
            target: targetLang,
            engine: engine,
            tone: selectedTone,
            settings: settings,
            glossary: glossary
        )
        if let hit = cache[key] {
            touchCache(key)
            return TranslationResult(
                translatedText: hit.translatedText,
                detectedSourceLang: hit.detectedSourceLang,
                engine: hit.engine,
                alternatives: hit.alternatives,
                latencyMs: hit.latencyMs,
                error: hit.error,
                isCached: true
            )
        }

        let result: TranslationResult
        switch engine {
        case .deepL:
            do {
                result = try await DeepLEngine.shared.translate(
                    text: text,
                    sourceLang: sourceLang,
                    targetLang: targetLang,
                    tone: selectedTone,
                    authKey: settings.deepLAuthKey,
                    isPro: settings.deepLIsPro,
                    customEndpoint: settings.deepLCustomEndpoint.isEmpty ? nil : settings.deepLCustomEndpoint
                )
            } catch {
                // Smart mode silently falls back to the Instant engine.
                guard selectedEngine == .smart else { throw error }
                return try await FastEngine.shared.translate(text: text, sourceLang: sourceLang, targetLang: targetLang)
            }

        case .ai:
            result = try await AIEngine.shared.translate(
                text: text,
                sourceLang: sourceLang,
                targetLang: targetLang,
                tone: selectedTone,
                provider: settings.aiProvider,
                apiKey: settings.aiApiKey,
                model: settings.aiModel,
                customEndpoint: settings.aiEndpoint.isEmpty ? nil : settings.aiEndpoint,
                glossary: glossary
            )

        case .fast, .smart:
            result = try await FastEngine.shared.translate(
                text: text,
                sourceLang: sourceLang,
                targetLang: targetLang
            )
        }

        storeInCache(key, result)
        return result
    }

    // MARK: - Cache

    private func touchCache(_ key: String) {
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
    }

    private func storeInCache(_ key: String, _ result: TranslationResult) {
        guard !result.translatedText.isEmpty, result.error == nil else { return }
        cache[key] = result
        touchCache(key)
        while cacheOrder.count > cacheLimit {
            let evicted = cacheOrder.removeFirst()
            cache.removeValue(forKey: evicted)
        }
    }

    static func cacheKey(
        text: String,
        source: String,
        target: String,
        engine: TranslationEngineType,
        tone: TranslationTone,
        settings: AppSettings,
        glossary: [GlossaryItem]
    ) -> String {
        let activeGlossary = glossary
            .filter { $0.isEnabled }
            .map { "\($0.sourceLang)|\($0.targetLang)|\($0.sourceTerm)=\($0.targetTerm)" }
            .joined(separator: ";")
        let extras: String
        switch engine {
        case .deepL:
            extras = "pro=\(settings.deepLIsPro)"
        case .ai:
            extras = "\(settings.aiProvider.rawValue)|\(settings.aiModel)"
        case .fast, .smart:
            extras = ""
        }
        return [text, source, target, engine.rawValue, tone.rawValue, extras, activeGlossary]
            .joined(separator: "\u{1E}")
    }

    // MARK: - Actions
    public func swapLanguages() {
        guard sourceLang != "auto" else { return }
        let temp = sourceLang
        sourceLang = targetLang
        targetLang = temp
        sourceText = translatedText
        triggerTranslation()
    }

    public func copyTranslation() {
        ClipboardMonitor.shared.ignoreNextChange()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(translatedText, forType: .string)
    }

    public func pasteAndTranslate() {
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            let clean = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty && clean != sourceText {
                sourceText = clean
                triggerTranslation()
            }
        }
    }

    public func speakSource() {
        TTSManager.shared.speak(text: sourceText, langCode: sourceLang == "auto" ? "en" : sourceLang)
    }

    public func speakTranslation() {
        TTSManager.shared.speak(text: translatedText, langCode: targetLang)
    }

    /// Kept for source compatibility; engines already run `TextSanitizer`.
    public static func sanitize(_ input: String) -> String {
        TextSanitizer.clean(input)
    }
}
