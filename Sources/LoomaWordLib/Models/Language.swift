import Foundation

public struct Language: Identifiable, Hashable, Codable {
    public var id: String { code }
    public let code: String
    public let name: String
    public let nativeName: String
    public let flag: String
    /// Whether the DeepL API accepts the `formality` parameter for this language as a
    /// *target*. DeepL rejects `formality` for other languages (e.g. Indonesian), so this
    /// must mirror DeepL's own list — not a guess. DeepL's `prefer_more`/`prefer_less`
    /// values are accepted for every target language.
    public let supportsFormality: Bool

    public init(code: String, name: String, nativeName: String, flag: String, supportsFormality: Bool = false) {
        self.code = code
        self.name = name
        self.nativeName = nativeName
        self.flag = flag
        self.supportsFormality = supportsFormality
    }

    public static let auto = Language(code: "auto", name: "Detect Language", nativeName: "Otomatis", flag: "✨", supportsFormality: false)

    public static let allLanguages: [Language] = [
        Language(code: "en", name: "English", nativeName: "English", flag: "🇺🇸", supportsFormality: false),
        Language(code: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩", supportsFormality: false),
        Language(code: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵", supportsFormality: true),
        Language(code: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪", supportsFormality: true),
        Language(code: "fr", name: "French", nativeName: "Français", flag: "🇫🇷", supportsFormality: true),
        Language(code: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸", supportsFormality: true),
        Language(code: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹", supportsFormality: true),
        Language(code: "zh", name: "Chinese (Simplified)", nativeName: "简体中文", flag: "🇨🇳", supportsFormality: false),
        Language(code: "zh-TW", name: "Chinese (Traditional)", nativeName: "繁體中文", flag: "🇹🇼", supportsFormality: false),
        Language(code: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷", supportsFormality: false),
        Language(code: "pt", name: "Portuguese", nativeName: "Português", flag: "🇵🇹", supportsFormality: true),
        Language(code: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺", supportsFormality: true),
        Language(code: "nl", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱", supportsFormality: true),
        Language(code: "pl", name: "Polish", nativeName: "Polski", flag: "🇵🇱", supportsFormality: true),
        Language(code: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦", supportsFormality: false),
        Language(code: "tr", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷", supportsFormality: false),
        Language(code: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳", supportsFormality: true),
        Language(code: "th", name: "Thai", nativeName: "ไทย", flag: "🇹🇭", supportsFormality: false),
        Language(code: "hi", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳", supportsFormality: false),
        Language(code: "uk", name: "Ukrainian", nativeName: "Українська", flag: "🇺🇦", supportsFormality: false),
        Language(code: "sv", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪", supportsFormality: false),
        Language(code: "da", name: "Danish", nativeName: "Dansk", flag: "🇩🇰", supportsFormality: false),
        Language(code: "fi", name: "Finnish", nativeName: "Suomi", flag: "🇫🇮", supportsFormality: false),
        Language(code: "cs", name: "Czech", nativeName: "Čeština", flag: "🇨🇿", supportsFormality: false),
        Language(code: "el", name: "Greek", nativeName: "Ελληνικά", flag: "🇬🇷", supportsFormality: false)
    ]

    public static func find(code: String) -> Language? {
        let clean = code.lowercased().split(separator: "-").first.map(String.init) ?? code.lowercased()
        return allLanguages.first { $0.code.lowercased() == code.lowercased() }
            ?? allLanguages.first { $0.code.lowercased().hasPrefix(clean) }
    }
}
