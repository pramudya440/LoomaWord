import Foundation
import os

public final class StorageManager {
    public static let shared = StorageManager()

    private let fileManager = FileManager.default
    private let appSupportDir: URL
    private let logger = Logger(subsystem: "com.pramudya.loomaword", category: "storage")

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

    // MARK: - Generic JSON I/O

    /// Atomic write — a crash mid-write can no longer truncate the file.
    private func write(_ data: Data, to url: URL) {
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to write \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Read a JSON file; if it exists but is corrupt, move it aside instead of
    /// silently overwriting the user's data with defaults on the next save.
    private func read<T>(_ type: T.Type, from url: URL, fallback: () -> T) -> T where T: Decodable {
        guard fileManager.fileExists(atPath: url.path) else { return fallback() }
        guard let data = try? Data(contentsOf: url) else {
            backupCorrupt(url)
            return fallback()
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            logger.error("Corrupt \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            backupCorrupt(url)
            return fallback()
        }
    }

    private func backupCorrupt(_ url: URL) {
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = url.appendingPathExtension("corrupt-\(stamp).json")
        try? fileManager.moveItem(at: url, to: backup)
        logger.warning("Backed up corrupt file to \(backup.lastPathComponent, privacy: .public)")
    }

    // MARK: - Settings
    public func loadSettings() -> AppSettings {
        read(AppSettings.self, from: settingsURL) {
            let defaults = AppSettings()
            self.saveSettings(defaults)
            return defaults
        }
    }

    public func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            write(data, to: settingsURL)
        }
    }

    // MARK: - Glossary
    public func loadGlossary() -> [GlossaryItem] {
        read([GlossaryItem].self, from: glossaryURL) {
            let samples: [GlossaryItem] = [
                GlossaryItem(sourceTerm: "pipeline", targetTerm: "alur kerja", sourceLang: "en", targetLang: "id", notes: "Konteks rekayasa perangkat lunak"),
                GlossaryItem(sourceTerm: "prompt engineering", targetTerm: "rekayasa prompt", sourceLang: "en", targetLang: "id", notes: "Konteks AI"),
                GlossaryItem(sourceTerm: "bug", targetTerm: "kutu sistem", sourceLang: "en", targetLang: "id", isEnabled: false, notes: "Istilah teknis"),
                GlossaryItem(sourceTerm: "deploy", targetTerm: "menerapkan", sourceLang: "en", targetLang: "id", notes: "Rilis sistem")
            ]
            self.saveGlossary(samples)
            return samples
        }
    }

    public func saveGlossary(_ items: [GlossaryItem]) {
        if let data = try? JSONEncoder().encode(items) {
            write(data, to: glossaryURL)
        }
    }

    // MARK: - History
    public func loadHistory() -> [TranslationHistoryItem] {
        read([TranslationHistoryItem].self, from: historyURL) { [] }
    }

    public func saveHistory(_ items: [TranslationHistoryItem]) {
        let trimmed = Array(items.prefix(250))
        if let data = try? JSONEncoder().encode(trimmed) {
            write(data, to: historyURL)
        }
    }

    public func clearHistory() {
        saveHistory([])
    }
}
