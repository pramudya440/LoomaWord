import Foundation
import Combine
import AppKit

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

    @Published public var settings: AppSettings
    @Published public var glossary: [GlossaryItem] = []
    @Published public var history: [TranslationHistoryItem] = []

    private var translateTask: Task<Void, Never>?
    private let storage = StorageManager.shared

    private init() {
        self.settings = storage.loadSettings()
        self.glossary = storage.loadGlossary()
        self.history = storage.loadHistory()

        self.selectedEngine = settings.preferredEngine
        self.selectedTone = settings.selectedTone
        self.sourceLang = settings.defaultSourceLang
        self.targetLang = settings.defaultTargetLang
    }

    public func saveSettings() {
        settings.preferredEngine = selectedEngine
        settings.selectedTone = selectedTone
        settings.defaultSourceLang = sourceLang
        settings.defaultTargetLang = targetLang
        storage.saveSettings(settings)
    }

    public func saveGlossary() {
        storage.saveGlossary(glossary)
    }

    // MARK: - Translation Execution
    public func triggerTranslation(debounce: Bool = false) {
        translateTask?.cancel()

        let text = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            self.translatedText = ""
            self.alternatives = []
            self.statusMessage = ""
            self.errorMessage = nil
            return
        }

        translateTask = Task {
            if debounce {
                try? await Task.sleep(nanoseconds: 350_000_000) // 350ms debounce
            }
            guard !Task.isCancelled else { return }

            self.isTranslating = true
            self.errorMessage = nil
            self.statusMessage = "Menerjemahkan..."

            do {
                let result = try await executeTranslation(text: text)
                guard !Task.isCancelled else { return }

                self.translatedText = result.translatedText
                self.alternatives = result.alternatives
                self.latencyMs = result.latencyMs
                self.statusMessage = "\(result.engine) • \(Int(result.latencyMs)) ms"

                if let detected = result.detectedSourceLang, self.sourceLang == "auto" {
                    // Update UI indicator with detected language
                    let name = Language.find(code: detected)?.name ?? detected.uppercased()
                    self.statusMessage += " (\(name))"
                }

                // Add to history
                let item = TranslationHistoryItem(
                    sourceText: text,
                    translatedText: result.translatedText,
                    sourceLang: self.sourceLang,
                    targetLang: self.targetLang,
                    engineUsed: result.engine,
                    toneUsed: self.selectedTone.rawValue
                )
                self.storage.addHistoryItem(item)
                self.history = self.storage.loadHistory()

                if self.settings.playSpeechAfterTranslation {
                    TTSManager.shared.speak(text: result.translatedText, langCode: self.targetLang)
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
                self.statusMessage = "Gagal menerjemahkan"
            }

            self.isTranslating = false
        }
    }

    private func executeTranslation(text: String) async throws -> TranslationResult {
        let engineToUse: TranslationEngineType

        if selectedEngine == .smart {
            if !settings.deepLAuthKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                engineToUse = .deepL
            } else if !settings.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || settings.aiProvider == .ollama {
                engineToUse = .ai
            } else {
                engineToUse = .fast
            }
        } else {
            engineToUse = selectedEngine
        }

        switch engineToUse {
        case .deepL:
            do {
                return try await DeepLEngine.shared.translate(
                    text: text,
                    sourceLang: sourceLang,
                    targetLang: targetLang,
                    tone: selectedTone,
                    authKey: settings.deepLAuthKey,
                    isPro: settings.deepLIsPro,
                    customEndpoint: settings.deepLCustomEndpoint.isEmpty ? nil : settings.deepLCustomEndpoint
                )
            } catch {
                // If DeepL fails and was auto/smart or user wants fallback, try FastEngine
                if selectedEngine == .smart {
                    return try await FastEngine.shared.translate(text: text, sourceLang: sourceLang, targetLang: targetLang)
                }
                throw error
            }

        case .ai:
            return try await AIEngine.shared.translate(
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
            return try await FastEngine.shared.translate(
                text: text,
                sourceLang: sourceLang,
                targetLang: targetLang
            )
        }
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
}
