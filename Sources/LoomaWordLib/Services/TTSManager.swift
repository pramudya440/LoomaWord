import Foundation
import AVFoundation

@MainActor
public final class TTSManager: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = TTSManager()

    private let synthesizer = AVSpeechSynthesizer()

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// ISO 639-1 (or 639-3) → preferred BCP-47 locale.
    static let localeMap: [String: String] = [
        "id": "id-ID", "en": "en-US", "ja": "ja-JP", "ko": "ko-KR",
        "zh": "zh-CN", "zh-cn": "zh-CN", "zh-tw": "zh-TW", "zh-hant": "zh-TW",
        "de": "de-DE", "fr": "fr-FR", "es": "es-ES", "it": "it-IT",
        "ru": "ru-RU", "ar": "ar-SA", "pt": "pt-BR", "nl": "nl-NL",
        "pl": "pl-PL", "sv": "sv-SE", "da": "da-DK", "fi": "fi-FI",
        "cs": "cs-CZ", "el": "el-GR", "tr": "tr-TR", "vi": "vi-VN",
        "th": "th-TH", "hi": "hi-IN", "uk": "uk-UA", "he": "he-IL",
        "nb": "nb-NO", "nn": "nn-NO", "ca": "ca-ES", "ro": "ro-RO",
        "hu": "hu-HU", "fa": "fa-IR", "ms": "ms-MY", "bn": "bn-IN",
        "ta": "ta-IN", "te": "te-IN", "fil": "fil-PH", "sw": "sw-KE",
        "hy": "hy-AM", "az": "az-AZ", "kk": "kk-KZ", "ur": "ur-PK",
    ]

    /// Best available voice for a language code: exact locale → prefix match among
    /// installed voices → English fallback. Covers languages the old hard-coded
    /// switch missed (pt, nl, pl, sv, … used to read in English).
    static func bestVoice(for langCode: String) -> AVSpeechSynthesisVoice? {
        let code = langCode.lowercased()
        var candidates: [String] = []
        if let mapped = localeMap[code] { candidates.append(mapped) }
        candidates.append(code)

        for candidate in candidates {
            if let voice = AVSpeechSynthesisVoice(language: candidate) {
                return voice
            }
        }

        let installed = AVSpeechSynthesisVoice.speechVoices()
        for candidate in candidates {
            if let voice = installed.first(where: { $0.language.lowercased().hasPrefix(candidate) }) {
                return voice
            }
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    public func speak(text: String, langCode: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: clean)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = Self.bestVoice(for: langCode)

        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
