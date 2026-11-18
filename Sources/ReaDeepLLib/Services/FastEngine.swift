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

        let src = sourceLang == "auto" ? "en" : sourceLang
        let pair = "\(src)|\(targetLang)"

        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=\(pair)") else {
            throw NSError(domain: "FastEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Gagal membuat URL permintaan terjemahan."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "FastEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Gagal menghubungi server terjemahan cepat."])
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
        let mainTranslation = decoded.responseData.translatedText

        // Gather alternative matches if available
        var alternatives: [String] = []
        if let matches = decoded.matches {
            for m in matches {
                let clean = m.translation.trimmingCharacters(in: .whitespacesAndNewlines)
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
            engine: "Instant Engine",
            alternatives: alternatives,
            latencyMs: latency
        )
    }
}
