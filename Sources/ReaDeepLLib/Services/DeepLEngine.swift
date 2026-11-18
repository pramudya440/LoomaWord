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

        let baseURL: String
        if let custom = customEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            baseURL = custom
        } else if isPro || !trimmedKey.hasSuffix(":fx") {
            baseURL = "https://api.deepl.com/v2/translate"
        } else {
            baseURL = "https://api-free.deepl.com/v2/translate"
        }

        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "DeepLEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid DeepL endpoint URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ReaDeepL-macOS/1.0", forHTTPHeaderField: "User-Agent")

        // Map tone to DeepL formality
        var formalityString: String? = nil
        switch tone {
        case .formal, .business, .academic:
            formalityString = "prefer_more"
        case .informal, .creative:
            formalityString = "prefer_less"
        case .standard:
            formalityString = "default"
        }

        var bodyDict: [String: Any] = [
            "text": [text],
            "target_lang": targetLang.uppercased()
        ]

        if sourceLang != "auto" {
            bodyDict["source_lang"] = sourceLang.uppercased()
        }

        if let form = formalityString {
            bodyDict["formality"] = form
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "DeepLEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Respons jaringan tidak valid."])
        }

        if httpResponse.statusCode == 403 || httpResponse.statusCode == 401 {
            throw NSError(domain: "DeepLEngine", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Autentikasi DeepL gagal. Periksa kembali API Key Anda (Free vs Pro)."])
        } else if httpResponse.statusCode == 456 {
            throw NSError(domain: "DeepLEngine", code: 456, userInfo: [NSLocalizedDescriptionKey: "Kuota karakter DeepL Anda telah habis."])
        } else if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "DeepLEngine", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "DeepL Error: \(errorMsg)"])
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
            translatedText: first.text,
            detectedSourceLang: first.detected_source_language?.lowercased(),
            engine: "DeepL Pro",
            alternatives: [],
            latencyMs: latency
        )
    }
}
