import Foundation

public struct GlossaryItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var sourceTerm: String
    public var targetTerm: String
    public var sourceLang: String
    public var targetLang: String
    public var isEnabled: Bool
    public var notes: String

    public init(id: UUID = UUID(), sourceTerm: String, targetTerm: String, sourceLang: String = "en", targetLang: String = "id", isEnabled: Bool = true, notes: String = "") {
        self.id = id
        self.sourceTerm = sourceTerm
        self.targetTerm = targetTerm
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.isEnabled = isEnabled
        self.notes = notes
    }
}

public struct TranslationHistoryItem: Identifiable, Codable {
    public var id: UUID
    public var timestamp: Date
    public var sourceText: String
    public var translatedText: String
    public var sourceLang: String
    public var targetLang: String
    public var engineUsed: String
    public var toneUsed: String
    public var isFavorite: Bool

    public init(id: UUID = UUID(), timestamp: Date = Date(), sourceText: String, translatedText: String, sourceLang: String, targetLang: String, engineUsed: String, toneUsed: String, isFavorite: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.engineUsed = engineUsed
        self.toneUsed = toneUsed
        self.isFavorite = isFavorite
    }
}

public struct TranslationResult: Equatable {
    public let translatedText: String
    public let detectedSourceLang: String?
    public let engine: String
    public let alternatives: [String]
    public let latencyMs: Double
    public let error: String?

    public init(translatedText: String, detectedSourceLang: String? = nil, engine: String, alternatives: [String] = [], latencyMs: Double = 0, error: String? = nil) {
        self.translatedText = translatedText
        self.detectedSourceLang = detectedSourceLang
        self.engine = engine
        self.alternatives = alternatives
        self.latencyMs = latencyMs
        self.error = error
    }

    public static func failure(_ message: String, engine: String) -> TranslationResult {
        return TranslationResult(translatedText: "", engine: engine, error: message)
    }
}
