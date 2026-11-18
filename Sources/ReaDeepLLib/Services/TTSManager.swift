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

    public func speak(text: String, langCode: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate

        let bcp47: String
        switch langCode.lowercased() {
        case "id": bcp47 = "id-ID"
        case "en": bcp47 = "en-US"
        case "ja": bcp47 = "ja-JP"
        case "ko": bcp47 = "ko-KR"
        case "zh": bcp47 = "zh-CN"
        case "zh-tw": bcp47 = "zh-TW"
        case "de": bcp47 = "de-DE"
        case "fr": bcp47 = "fr-FR"
        case "es": bcp47 = "es-ES"
        case "it": bcp47 = "it-IT"
        case "ru": bcp47 = "ru-RU"
        case "ar": bcp47 = "ar-SA"
        default: bcp47 = langCode
        }

        if let voice = AVSpeechSynthesisVoice(language: bcp47) {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
