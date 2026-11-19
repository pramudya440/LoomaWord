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

    public var defaultModel: String {
        switch self {
        case .gemini: return "gemini-1.5-flash"
        case .openai: return "gpt-4o-mini"
        case .ollama: return "llama3.2"
        case .custom: return "default"
        }
    }

    public var defaultEndpoint: String {
        switch self {
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/models"
        case .openai: return "https://api.openai.com/v1/chat/completions"
        case .ollama: return "http://localhost:11434/v1/chat/completions"
        case .custom: return "https://api.deepseek.com/v1/chat/completions"
        }
    }
}

public struct AppSettings: Codable {
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
    public var aiModel: String = "gemini-1.5-flash"
    public var aiEndpoint: String = ""

    // UX
    public var autoTranslateClipboard: Bool = true
    public var instantTranslateAsYouType: Bool = true
    public var playSpeechAfterTranslation: Bool = false
    public var globalHotkeyString: String = "⌥ + Space"
    public var stayOnTop: Bool = true
    public var soundEffects: Bool = true
    public var showMenuBarIcon: Bool = true

    public init() {}
}
