import Foundation

public final class DeepLEngine {
    public static let shared = DeepLEngine()

    private init() {}

    public func translate(
        text: String,
        sourceLang: String,
        targetLang: String,
        tone: TranslationTone,
        authKey: String,
        isPro: Bool,
        customEndpoint: String?
    ) async throws -> TranslationResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        let trimmedKey = authKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "DeepLEngine", code: 401, userInfo: [NSLocalizedDescriptionKey: "DeepL API Key belum diatur. Masukkan API key di Pengaturan atau gunakan AI/Instant Engine."])
        }

        guard let target = Self.deepLTargetCode(targetLang) else {
            throw NSError(domain: "DeepLEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Bahasa tujuan \"\(targetLang)\" tidak didukung DeepL. Pilih bahasa lain atau gunakan AI/Instant Engine."])
        }

        let baseURL = Self.endpoint(isPro: isPro, authKey: trimmedKey, customEndpoint: customEndpoint)
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "DeepLEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid DeepL endpoint URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("LoomaWord-macOS/1.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: Self.buildBody(text: text, sourceLang: sourceLang, targetLang: target, tone: tone)
        )

        let response: HTTPClient.Response
        do {
            response = try await HTTPClient.send(request, timeout: 30, maxAttempts: 3)
        } catch let error as HTTPClient.ClientError {
            // DeepL rejects `formality` for languages that don't support it. Retry once
            // without the parameter instead of surfacing a cryptic 400.
            if case .http(let status, _, _) = error, status == 400 {
                var retryBody = Self.buildBody(text: text, sourceLang: sourceLang, targetLang: target, tone: tone)
                guard retryBody["formality"] != nil else { throw Self.mapError(error) }
                retryBody.removeValue(forKey: "formality")
                request.httpBody = try JSONSerialization.data(withJSONObject: retryBody)
                let retry = try await HTTPClient.send(request, timeout: 30, maxAttempts: 1)
                return try Self.parse(retry, isPro: isPro, startTime: startTime)
            }
            throw Self.mapError(error)
        }

        return try Self.parse(response, isPro: isPro, startTime: startTime)
    }

    // MARK: - Pure helpers (unit-tested)

    /// DeepL rejects unknown target languages; map our codes to DeepL's.
    /// Returns nil when DeepL doesn't support the language at all.
    static func deepLTargetCode(_ code: String) -> String? {
        switch code.lowercased() {
        case "zh-tw", "zh-hant": return "ZH-HANT"
        case "zh", "zh-cn", "zh-hans": return "ZH"
        case "en": return "EN"
        case "pt": return "PT"
        case "th", "hi": return nil           // not supported as DeepL targets
        case "auto": return nil               // auto is a source-only concept
        default: return code.uppercased()
        }
    }

    /// Map tone to DeepL's `formality`, or nil when nothing should be sent.
    ///
    /// Never send `formality` for Standard tone: DeepL rejects the parameter for
    /// target languages that don't support it (e.g. Indonesian), and `default` adds
    /// nothing. `prefer_more` / `prefer_less` are accepted for *all* target languages.
    static func formalityParameter(tone: TranslationTone, targetLang: String) -> String? {
        switch tone {
        case .standard:
            return nil
        case .formal, .business, .academic:
            return "prefer_more"
        case .informal, .creative:
            return "prefer_less"
        }
    }

    static func buildBody(text: String, sourceLang: String, targetLang: String, tone: TranslationTone) -> [String: Any] {
        var body: [String: Any] = [
            "text": [text],
            "target_lang": targetLang
        ]
        if sourceLang != "auto", let source = deepLTargetCode(sourceLang) {
            body["source_lang"] = source
        }
        if let formality = formalityParameter(tone: tone, targetLang: targetLang) {
            body["formality"] = formality
        }
        return body
    }

    static func endpoint(isPro: Bool, authKey: String, customEndpoint: String?) -> String {
        if let custom = customEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return (isPro || !authKey.hasSuffix(":fx"))
            ? "https://api.deepl.com/v2/translate"
            : "https://api-free.deepl.com/v2/translate"
    }

    static func engineLabel(isPro: Bool) -> String {
        isPro ? "DeepL Pro" : "DeepL Free"
    }

    // MARK: - Response handling

    private static func parse(_ response: HTTPClient.Response, isPro: Bool, startTime: Double) throws -> TranslationResult {
        let data = response.data
        switch response.statusCode {
        case 200:
            break
        case 403, 401:
            throw NSError(domain: "DeepLEngine", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "Autentikasi DeepL gagal. Periksa kembali API Key Anda (Free vs Pro)."])
        case 456:
            throw NSError(domain: "DeepLEngine", code: 456, userInfo: [NSLocalizedDescriptionKey: "Kuota karakter DeepL Anda telah habis."])
        default:
            let errorMsg = HTTPClient.truncate(data)
            throw NSError(domain: "DeepLEngine", code: response.statusCode, userInfo: [NSLocalizedDescriptionKey: "DeepL Error: \(errorMsg)"])
        }

        struct DeepLResponse: Codable {
            struct Translation: Codable {
                let detected_source_language: String?
                let text: String
            }
            let translations: [Translation]
        }

        let decoded = try JSONDecoder().decode(DeepLResponse.self, from: data)
        guard let first = decoded.translations.first else {
            throw NSError(domain: "DeepLEngine", code: 404, userInfo: [NSLocalizedDescriptionKey: "Tidak ada terjemahan yang dihasilkan."])
        }

        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        return TranslationResult(
            translatedText: TextSanitizer.clean(first.text),
            detectedSourceLang: first.detected_source_language?.lowercased(),
            engine: engineLabel(isPro: isPro),
            alternatives: [],
            latencyMs: latency
        )
    }

    private static func mapError(_ error: HTTPClient.ClientError) -> NSError {
        switch error {
        case .http(let status, let body, _):
            if status == 403 || status == 401 {
                return NSError(domain: "DeepLEngine", code: status, userInfo: [NSLocalizedDescriptionKey: "Autentikasi DeepL gagal. Periksa kembali API Key Anda (Free vs Pro)."])
            }
            if status == 456 {
                return NSError(domain: "DeepLEngine", code: 456, userInfo: [NSLocalizedDescriptionKey: "Kuota karakter DeepL Anda telah habis."])
            }
            if status == 429 {
                return NSError(domain: "DeepLEngine", code: 429, userInfo: [NSLocalizedDescriptionKey: "Permintaan DeepL terlalu cepat (rate limit). Coba lagi sebentar lagi."])
            }
            return NSError(domain: "DeepLEngine", code: status, userInfo: [NSLocalizedDescriptionKey: "DeepL Error: \(body)"])
        case .network(let message):
            return NSError(domain: "DeepLEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gagal menghubungi DeepL: \(message)"])
        }
    }
}
