import Foundation

public enum TranslationEngineType: String, CaseIterable, Identifiable, Codable {
    case smart = "Smart (Auto)"
    case deepL = "DeepL API"
    case ai = "AI Pro (Gemini/OpenAI/Ollama)"
    case fast = "Instant Engine"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .smart: return "sparkles"
        case .deepL: return "bolt.shield.fill"
        case .ai: return "brain.head.profile"
        case .fast: return "bolt.fill"
        }
    }

    public var description: String {
        switch self {
        case .smart: return "Otomatis memilih engine terbaik yang tersedia"
        case .deepL: return "Kualitas resmi DeepL dengan dukungan Free/Pro Key"
        case .ai: return "Terjemahan kontekstual cerdas & tone modifier bertenaga LLM"
        case .fast: return "Terjemahan instan zero-config tanpa API key"
        }
    }
}

public enum TranslationTone: String, CaseIterable, Identifiable, Codable {
    case standard = "Standard"
    case formal = "Formal (Baku)"
    case informal = "Informal (Santai)"
    case business = "Business"
    case academic = "Academic"
    case creative = "Creative"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .standard: return "character.book.closed"
        case .formal: return "briefcase.fill"
        case .informal: return "bubble.left.and.bubble.right"
        case .business: return "chart.bar.doc.horizontal"
        case .academic: return "graduationcap.fill"
        case .creative: return "paintpalette.fill"
        }
    }

    public var promptInstruction: String {
        switch self {
        case .standard:
            return "Maintain a natural and balanced tone appropriate for general audience."
        case .formal:
            return "Use formal, polite, and grammatically precise language (e.g. bahasa baku/resmi, respectful honorifics, no slang)."
        case .informal:
            return "Use conversational, friendly, and natural everyday language (e.g. colloquial phrasing, natural contractions, casual vocabulary)."
        case .business:
            return "Use professional corporate business vocabulary, concise executive phrasing, and respectful commercial tone."
        case .academic:
            return "Use academic, scholarly, scholarly prose with precise terminology, objective register, and articulate structure."
        case .creative:
            return "Adapt idiomatically and creatively with rich phrasing and emotional nuance rather than literal word-by-word translation."
        }
    }
}

public enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case gemini = "Google Gemini"
    case openai = "OpenAI"
    case ollama = "Ollama (Local)"
    case custom = "Custom OpenAI-Compatible"

    public var id: String { rawValue }

    /// Default model for each provider.
    ///
    /// Only IDs that are currently *live* and confirmed by the provider docs should be
    /// used here. Retired IDs are migrated in `AppSettings.init(from:)` so existing
    /// installs keep working after a model is discontinued.
    public var defaultModel: String {
        switch self {
        case .gemini: return "gemini-flash-latest"   // always points at the newest Flash model
        case .openai: return "gpt-6-luna"
        case .ollama: return "llama3.2"
        case .custom: return "deepseek-chat"
        }
    }

    /// Models that have been shut down by their provider and must be replaced on load.
    public static let retiredModels: Set<String> = [
        "gemini-1.5-flash", "gemini-1.5-flash-001", "gemini-1.5-flash-002",
        "gemini-1.5-flash-8b-001", "gemini-1.5-pro", "gemini-1.5-pro-001", "gemini-1.5-pro-002",
        "gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-3.1-flash-lite-preview"
    ]

    public var defaultEndpoint: String {
        switch self {
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/models"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .ollama: return "http://localhost:11434/v1/chat/completions"
        case .custom: return "https://api.deepseek.com/v1/chat/completions"
        }
    }
}

/// User preferences.
///
/// Decoding is deliberately tolerant: every field falls back to its default when the
/// key is missing (or unparsable) so `settings.json` written by an older/newer build
/// never resets the user's stored values. Never change this to a synthesized decoder.
public struct AppSettings: Codable, Equatable {
    public var preferredEngine: TranslationEngineType = .smart
    public var selectedTone: TranslationTone = .standard
    public var defaultSourceLang: String = "auto"
    public var defaultTargetLang: String = "id"

    // DeepL
    public var deepLAuthKey: String = ""
    public var deepLIsPro: Bool = false
    public var deepLCustomEndpoint: String = ""

    // AI
    public var aiProvider: AIProvider = .gemini
    public var aiApiKey: String = ""
    public var aiModel: String = AIProvider.gemini.defaultModel
    public var aiEndpoint: String = ""

    // UX
    public var autoTranslateClipboard: Bool = true
    public var instantTranslateAsYouType: Bool = true
    public var playSpeechAfterTranslation: Bool = false
    public var showMenuBarIcon: Bool = true

    public init() {}

    enum CodingKeys: String, CodingKey {
        case preferredEngine, selectedTone, defaultSourceLang, defaultTargetLang
        case deepLAuthKey, deepLIsPro, deepLCustomEndpoint
        case aiProvider, aiApiKey, aiModel, aiEndpoint
        case autoTranslateClipboard, instantTranslateAsYouType, playSpeechAfterTranslation, showMenuBarIcon
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        preferredEngine = (try? c.decode(TranslationEngineType.self, forKey: .preferredEngine)) ?? .smart
        selectedTone = (try? c.decode(TranslationTone.self, forKey: .selectedTone)) ?? .standard
        defaultSourceLang = (try? c.decode(String.self, forKey: .defaultSourceLang)) ?? "auto"
        defaultTargetLang = (try? c.decode(String.self, forKey: .defaultTargetLang)) ?? "id"

        deepLAuthKey = (try? c.decode(String.self, forKey: .deepLAuthKey)) ?? ""
        deepLIsPro = (try? c.decode(Bool.self, forKey: .deepLIsPro)) ?? false
        deepLCustomEndpoint = (try? c.decode(String.self, forKey: .deepLCustomEndpoint)) ?? ""

        aiProvider = (try? c.decode(AIProvider.self, forKey: .aiProvider)) ?? .gemini
        aiApiKey = (try? c.decode(String.self, forKey: .aiApiKey)) ?? ""
        aiModel = (try? c.decode(String.self, forKey: .aiModel)) ?? aiProvider.defaultModel
        aiEndpoint = (try? c.decode(String.self, forKey: .aiEndpoint)) ?? ""

        autoTranslateClipboard = (try? c.decode(Bool.self, forKey: .autoTranslateClipboard)) ?? true
        instantTranslateAsYouType = (try? c.decode(Bool.self, forKey: .instantTranslateAsYouType)) ?? true
        playSpeechAfterTranslation = (try? c.decode(Bool.self, forKey: .playSpeechAfterTranslation)) ?? false
        showMenuBarIcon = (try? c.decode(Bool.self, forKey: .showMenuBarIcon)) ?? true

        // Providers retire model IDs; move users off models that are already shut down.
        if AIProvider.retiredModels.contains(aiModel) {
            aiModel = aiProvider.defaultModel
        }
        // Legacy builds stored an empty endpoint for Ollama.
        if aiProvider == .ollama && aiEndpoint.isEmpty {
            aiEndpoint = aiProvider.defaultEndpoint
        }
    }
}
