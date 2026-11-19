import Foundation

public final class StorageManager {
    public static let shared = StorageManager()

    private let fileManager = FileManager.default
    private let appSupportDir: URL

    private var settingsURL: URL { appSupportDir.appendingPathComponent("settings.json") }
    private var glossaryURL: URL { appSupportDir.appendingPathComponent("glossary.json") }
    private var historyURL: URL { appSupportDir.appendingPathComponent("history.json") }

    private init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let oldDir = base.appendingPathComponent("ReaDeepL", isDirectory: true)
        let newDir = base.appendingPathComponent("LoomaWord", isDirectory: true)

        // Automatically migrate existing data if present
        if fileManager.fileExists(atPath: oldDir.path) && !fileManager.fileExists(atPath: newDir.path) {
            try? fileManager.moveItem(at: oldDir, to: newDir)
        }

        appSupportDir = newDir
        try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
    }

    // MARK: - Settings
    public func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            let defaults = AppSettings()
            saveSettings(defaults)
            return defaults
        }
        return settings
    }

    public func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsURL)
        }
    }

    // MARK: - Glossary
    public func loadGlossary() -> [GlossaryItem] {
        guard let data = try? Data(contentsOf: glossaryURL),
              let items = try? JSONDecoder().decode([GlossaryItem].self, from: data) else {
            let samples: [GlossaryItem] = [
                GlossaryItem(sourceTerm: "pipeline", targetTerm: "alur kerja", sourceLang: "en", targetLang: "id", notes: "Konteks rekayasa perangkat lunak"),
                GlossaryItem(sourceTerm: "prompt engineering", targetTerm: "rekayasa prompt", sourceLang: "en", targetLang: "id", notes: "Konteks AI"),
                GlossaryItem(sourceTerm: "bug", targetTerm: "kutu sistem", sourceLang: "en", targetLang: "id", isEnabled: false, notes: "Istilah teknis"),
                GlossaryItem(sourceTerm: "deploy", targetTerm: "menerapkan", sourceLang: "en", targetLang: "id", notes: "Rilis sistem")
            ]
            saveGlossary(samples)
            return samples
        }
        return items
    }

    public func saveGlossary(_ items: [GlossaryItem]) {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: glossaryURL)
        }
    }

    // MARK: - History
    public func loadHistory() -> [TranslationHistoryItem] {
        guard let data = try? Data(contentsOf: historyURL),
              let history = try? JSONDecoder().decode([TranslationHistoryItem].self, from: data) else {
            return []
        }
        return history
    }

    public func saveHistory(_ items: [TranslationHistoryItem]) {
        // Keep latest 250 items
        let trimmed = Array(items.prefix(250))
        if let data = try? JSONEncoder().encode(trimmed) {
            try? data.write(to: historyURL)
        }
    }

    public func addHistoryItem(_ item: TranslationHistoryItem) {
        var current = loadHistory()
        // Deduplicate adjacent
        if let first = current.first, first.sourceText == item.sourceText && first.targetLang == item.targetLang {
            return
        }
        current.insert(item, at: 0)
        saveHistory(current)
    }

    public func clearHistory() {
        saveHistory([])
    }
}
