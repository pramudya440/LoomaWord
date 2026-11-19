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

    // MARK: - URL builders (pure, unit-tested)

    /// Google's unofficial endpoint. Uses manual percent-encoding so that `&`, `+`,
    /// `=` and `?` inside the text can never break out of the `q` parameter.
    static func googleURL(text: String, sourceLang: String, targetLang: String) -> URL? {
        HTTPClient.url(
            base: "https://translate.googleapis.com/translate_a/single",
            queryItems: [
                URLQueryItem(name: "client", value: "gtx"),
                URLQueryItem(name: "sl", value: sourceLang),
                URLQueryItem(name: "tl", value: targetLang),
                URLQueryItem(name: "dt", value: "t"),
                URLQueryItem(name: "dt", value: "at"),
                URLQueryItem(name: "q", value: text),
            ]
        )
    }

    /// MyMemory requires an explicit source language; `auto` is rejected by the API,
    /// so we send `Autodetect` instead of silently assuming English.
    static func myMemoryURL(text: String, sourceLang: String, targetLang: String) -> URL? {
        let source = sourceLang == "auto" ? "Autodetect" : sourceLang
        return HTTPClient.url(
            base: "https://api.mymemory.translated.net/get",
            queryItems: [
                URLQueryItem(name: "q", value: text),
                URLQueryItem(name: "langpair", value: "\(source)|\(targetLang)"),
            ]
        )
    }

    // MARK: - Google Translate
    private func translateWithGoogle(
        text: String,
        sourceLang: String,
        targetLang: String,
        startTime: Double
    ) async throws -> TranslationResult {
        guard let url = Self.googleURL(text: text, sourceLang: sourceLang, targetLang: targetLang) else {
            throw NSError(domain: "FastEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Gagal membuat URL Google Translate."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let response = try await HTTPClient.send(request, timeout: 7, maxAttempts: 2)
        guard response.statusCode == 200 else {
            throw NSError(domain: "FastEngine", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Google Translate tidak merespons 200 OK."])
        }

        guard let jsonArray = try JSONSerialization.jsonObject(with: response.data) as? [Any],
              let sentenceArray = jsonArray.first as? [[Any]] else {
            throw NSError(domain: "FastEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Format respons Google Translate tidak dikenali."])
        }

        var translatedPieces: [String] = []
        for piece in sentenceArray {
            if let str = piece.first as? String {
                translatedPieces.append(str)
            }
        }

        let cleanText = TextSanitizer.clean(translatedPieces.joined())

        var detectedLang: String? = nil
        if jsonArray.count > 2, let lang = jsonArray[2] as? String {
            detectedLang = lang
        }

        var alternatives: [String] = []
        if jsonArray.count > 1, let altGroup = jsonArray[1] as? [[Any]] {
            for group in altGroup {
                if group.count > 1, let words = group[1] as? [String] {
                    for w in words {
                        let cleanW = TextSanitizer.clean(w)
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
        guard sourceLang.lowercased() != targetLang.lowercased() else {
            throw NSError(domain: "FastEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Bahasa sama dan tujuan — tidak perlu diterjemahkan."])
        }
        guard let url = Self.myMemoryURL(text: text, sourceLang: sourceLang, targetLang: targetLang) else {
            throw NSError(domain: "FastEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Gagal membuat URL MyMemory."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let response = try await HTTPClient.send(request, timeout: 7, maxAttempts: 2)
        guard response.statusCode == 200 else {
            throw NSError(domain: "FastEngine", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gagal menghubungi server cadangan MyMemory."])
        }

        struct MyMemoryResponse: Codable {
            struct ResponseData: Codable {
                let translatedText: String
                let match: Double?
                let detectedLanguage: DetectedLanguage?
            }
            struct DetectedLanguage: Codable {
                let language: String?
                let confidence: Double?
            }
            struct MatchItem: Codable {
                let translation: String
            }
            let responseData: ResponseData
            let matches: [MatchItem]?
            let responseStatus: Int?
        }

        let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: response.data)
        if let status = decoded.responseStatus, status != 200 {
            throw NSError(domain: "FastEngine", code: status, userInfo: [NSLocalizedDescriptionKey: "MyMemory: \(decoded.responseData.translatedText)"])
        }

        let mainTranslation = TextSanitizer.clean(decoded.responseData.translatedText)
        guard !mainTranslation.isEmpty else {
            throw NSError(domain: "FastEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "MyMemory tidak mengembalikan terjemahan."])
        }

        var alternatives: [String] = []
        if let matches = decoded.matches {
            for m in matches {
                let clean = TextSanitizer.clean(m.translation)
                if !clean.isEmpty && clean.lowercased() != mainTranslation.lowercased() && !alternatives.contains(clean) {
                    alternatives.append(clean)
                }
                if alternatives.count >= 3 { break }
            }
        }

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        return TranslationResult(
            translatedText: mainTranslation,
            detectedSourceLang: decoded.responseData.detectedLanguage?.language ?? (sourceLang == "auto" ? nil : sourceLang),
            engine: "Instant Engine (Backup)",
            alternatives: alternatives,
            latencyMs: latency
        )
    }
}
