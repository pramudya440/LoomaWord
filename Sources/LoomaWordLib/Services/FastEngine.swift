import Foundation

public final class FastEngine {
    public static let shared = FastEngine()

    private init() {}

    public func translate(
        text: String,
        sourceLang: String,
        targetLang: String
    ) async throws -> TranslationResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. Try Google Translate API (High accuracy, no encoding quirks, fast)
        do {
            return try await translateWithGoogle(
                text: text,
                sourceLang: sourceLang,
                targetLang: targetLang,
                startTime: startTime
            )
        } catch {
            // 2. Fallback to MyMemory if Google is blocked or fails
            return try await translateWithMyMemory(
                text: text,
                sourceLang: sourceLang,
                targetLang: targetLang,
                startTime: startTime
            )
        }
    }

    // MARK: - Google Translate
    private func translateWithGoogle(
        text: String,
        sourceLang: String,
        targetLang: String,
        startTime: Double
    ) async throws -> TranslationResult {
        let sl = sourceLang == "auto" ? "auto" : sourceLang
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=\(sl)&tl=\(targetLang)&dt=t&dt=at&q=\(encoded)") else {
            throw NSError(domain: "FastEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Gagal membuat URL Google Translate."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 7.0

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "FastEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Google Translate tidak merespons 200 OK."])
        }

        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any],
              let sentenceArray = jsonArray.first as? [[Any]] else {
            throw NSError(domain: "FastEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Format respons Google Translate tidak dikenali."])
        }

        var translatedPieces: [String] = []
        for piece in sentenceArray {
            if let str = piece.first as? String {
                translatedPieces.append(str)
            }
        }

        let rawTranslation = translatedPieces.joined()
        let cleanText = sanitizeText(rawTranslation)

        var detectedLang: String? = nil
        if jsonArray.count > 2, let lang = jsonArray[2] as? String {
            detectedLang = lang
        }

        var alternatives: [String] = []
        if jsonArray.count > 1, let altGroup = jsonArray[1] as? [[Any]] {
            for group in altGroup {
                if group.count > 1, let words = group[1] as? [String] {
                    for w in words {
                        let cleanW = sanitizeText(w)
                        if !cleanW.isEmpty && cleanW.lowercased() != cleanText.lowercased() && !alternatives.contains(cleanW) {
                            alternatives.append(cleanW)
                        }
                        if alternatives.count >= 4 { break }
                    }
                }
            }
        }

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        return TranslationResult(
            translatedText: cleanText,
            detectedSourceLang: detectedLang,
            engine: "Instant Engine",
            alternatives: alternatives,
            latencyMs: latency
        )
    }

    // MARK: - MyMemory Fallback
    private func translateWithMyMemory(
        text: String,
        sourceLang: String,
        targetLang: String,
        startTime: Double
    ) async throws -> TranslationResult {
        let src = sourceLang == "auto" ? "en" : sourceLang
        let pair = "\(src)|\(targetLang)"

        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=\(pair)") else {
            throw NSError(domain: "FastEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Gagal membuat URL MyMemory."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 7.0

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "FastEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Gagal menghubungi server cadangan MyMemory."])
        }

        struct MyMemoryResponse: Codable {
            struct ResponseData: Codable {
                let translatedText: String
                let match: Double?
            }
            struct MatchItem: Codable {
                let translation: String
            }
            let responseData: ResponseData
            let matches: [MatchItem]?
        }

        let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
        let mainTranslation = sanitizeText(decoded.responseData.translatedText)

        var alternatives: [String] = []
        if let matches = decoded.matches {
            for m in matches {
                let clean = sanitizeText(m.translation)
                if !clean.isEmpty && clean.lowercased() != mainTranslation.lowercased() && !alternatives.contains(clean) {
                    alternatives.append(clean)
                }
                if alternatives.count >= 3 { break }
            }
        }

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        return TranslationResult(
            translatedText: mainTranslation,
            detectedSourceLang: sourceLang == "auto" ? nil : sourceLang,
            engine: "Instant Engine (Backup)",
            alternatives: alternatives,
            latencyMs: latency
        )
    }

    // MARK: - Text Sanitizer (Fixes %20 and HTML entities)
    private func sanitizeText(_ input: String) -> String {
        var text = input

        // 1. Decode percent encodings (fixes e.g. %20, %21, %2C, etc.)
        if text.contains("%") {
            if let decoded = text.removingPercentEncoding {
                text = decoded
            }
            // Secondary regex/replace in case of malformed percent sequences
            text = text.replacingOccurrences(of: "%20", with: " ")
            text = text.replacingOccurrences(of: "%2C", with: ",")
            text = text.replacingOccurrences(of: "%2E", with: ".")
            text = text.replacingOccurrences(of: "%3F", with: "?")
            text = text.replacingOccurrences(of: "%21", with: "!")
            text = text.replacingOccurrences(of: "%27", with: "'")
            text = text.replacingOccurrences(of: "%22", with: "\"")
        }

        // 2. Decode common HTML entities
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
