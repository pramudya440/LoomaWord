import Foundation

public final class AIEngine {
    public static let shared = AIEngine()

    private init() {}

    public func translate(
        text: String,
        sourceLang: String,
        targetLang: String,
        tone: TranslationTone,
        provider: AIProvider,
        apiKey: String,
        model: String,
        customEndpoint: String?,
        glossary: [GlossaryItem]
    ) async throws -> TranslationResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        let srcName = Language.find(code: sourceLang)?.name ?? (sourceLang == "auto" ? "any language" : sourceLang)
        let tgtName = Language.find(code: targetLang)?.name ?? targetLang

        let systemPrompt = """
        You are LoomaWord AI, a world-class translation engine and professional linguist.
        Translate the provided text from \(srcName) to \(tgtName).

        Tone/Style Specification:
        \(tone.promptInstruction)
        \(Self.glossaryRule(glossary, sourceLang: sourceLang, targetLang: targetLang))

        Rules:
        1. Produce an exceptionally natural, nuanced translation matching the specified tone.
        2. Never output meta-commentary, markdown ticks, or explanations.
        3. Respond ONLY with a valid JSON object in this exact schema:
        {
          "translation": "translated text here",
          "detected_source_language": "2-letter ISO code (e.g. en, id, ja)",
          "alternatives": ["alternative translation 1", "alternative translation 2"]
        }
        """

        // Never fall back to a hardcoded (possibly retired) model ID.
        let resolvedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? provider.defaultModel
            : model

        switch provider {
        case .gemini:
            return try await translateGemini(
                text: text,
                systemPrompt: systemPrompt,
                apiKey: apiKey,
                model: resolvedModel,
                startTime: startTime
            )
        case .openai, .ollama, .custom:
            return try await translateOpenAICompatible(
                text: text,
                systemPrompt: systemPrompt,
                provider: provider,
                apiKey: apiKey,
                model: resolvedModel,
                customEndpoint: customEndpoint,
                startTime: startTime
            )
        }
    }

    // MARK: - Prompt helpers (pure, unit-tested)

    /// Only apply glossary entries that match the active language pair (or are
    /// language-agnostic), so an en→id rule never leaks into a ja→en translation.
    static func glossaryRule(_ glossary: [GlossaryItem], sourceLang: String, targetLang: String) -> String {
        let src = sourceLang.lowercased()
        let tgt = targetLang.lowercased()

        let active = glossary.filter { item in
            guard item.isEnabled,
                  !item.sourceTerm.isEmpty,
                  !item.targetTerm.isEmpty else { return false }
            let itemSrc = item.sourceLang.lowercased()
            let itemTgt = item.targetLang.lowercased()
            // Match exact pair, reversed pair, or wildcard-ish entries.
            if itemSrc == src && itemTgt == tgt { return true }
            if itemSrc == "auto" || itemTgt == "auto" { return true }
            return false
        }

        guard !active.isEmpty else { return "" }
        let terms = active.map { "- '\($0.sourceTerm)' must be translated as '\($0.targetTerm)'" }
            .joined(separator: "\n")
        return "\n\nStrict Glossary Rules:\n\(terms)"
    }

    // MARK: - Gemini API
    private func translateGemini(
        text: String,
        systemPrompt: String,
        apiKey: String,
        model: String,
        startTime: Double
    ) async throws -> TranslationResult {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw NSError(domain: "AIEngine", code: 401, userInfo: [NSLocalizedDescriptionKey: "Gemini API Key belum diisi di Pengaturan."])
        }

        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            throw NSError(domain: "AIEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "URL Gemini tidak valid."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": systemPrompt]
                ]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": text]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2,
                "response_mime_type": "application/json"
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let response: HTTPClient.Response
        do {
            response = try await HTTPClient.send(request, timeout: 45, maxAttempts: 2)
        } catch let error as HTTPClient.ClientError {
            throw Self.geminiError(error)
        }
        guard response.statusCode == 200 else {
            throw Self.geminiError(.http(status: response.statusCode, body: HTTPClient.truncate(response.data), retryAfter: nil))
        }

        struct GeminiResponse: Codable {
            struct Candidate: Codable {
                struct Content: Codable {
                    struct Part: Codable {
                        let text: String?
                    }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]?
        }

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: response.data)
        guard let jsonText = decoded.candidates?.first?.content.parts.first?.text else {
            throw NSError(domain: "AIEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Gemini tidak mengembalikan teks jawaban."])
        }

        return Self.parseJSONResult(jsonText, engineName: "Gemini (\(model))", startTime: startTime, fallbackText: jsonText)
    }

    private static func geminiError(_ error: HTTPClient.ClientError) -> NSError {
        switch error {
        case .http(let status, let body, _):
            let hint: String
            switch status {
            case 400: hint = "Permintaan ditolak — model mungkin tidak tersedia atau API key salah."
            case 401, 403: hint = "Gemini API Key tidak valid atau tidak berwenang."
            case 429: hint = "Batas permintaan Gemini tercapai (rate limit). Coba lagi nanti."
            default: hint = "Gemini Error: \(body)"
            }
            return NSError(domain: "AIEngine", code: status, userInfo: [NSLocalizedDescriptionKey: hint])
        case .network(let message):
            return NSError(domain: "AIEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gagal menghubungi Gemini: \(message)"])
        }
    }

    // MARK: - OpenAI / Ollama / Custom API
    private func translateOpenAICompatible(
        text: String,
        systemPrompt: String,
        provider: AIProvider,
        apiKey: String,
        model: String,
        customEndpoint: String?,
        startTime: Double
    ) async throws -> TranslationResult {
        let endpointString: String
        if let custom = customEndpoint?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            endpointString = custom
        } else {
            endpointString = provider.defaultEndpoint
        }

        guard let url = URL(string: endpointString) else {
            throw NSError(domain: "AIEngine", code: 400, userInfo: [NSLocalizedDescriptionKey: "Endpoint AI URL tidak valid."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty && provider != .ollama {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        func makePayload(includeResponseFormat: Bool) -> [String: Any] {
            var payload: [String: Any] = [
                "model": model,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": text]
                ],
                "temperature": 0.2
            ]
            // Some servers (older Ollama, custom proxies) reject `response_format`.
            if includeResponseFormat {
                payload["response_format"] = ["type": "json_object"]
            }
            return payload
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: makePayload(includeResponseFormat: true))

        let response: HTTPClient.Response
        do {
            response = try await HTTPClient.send(request, timeout: 60, maxAttempts: 2)
        } catch let error as HTTPClient.ClientError {
            if case .http(400, _, _) = error {
                // Retry once without response_format — many OpenAI-compatible servers
                // don't support it but the rest of the request is fine.
                request.httpBody = try JSONSerialization.data(withJSONObject: makePayload(includeResponseFormat: false))
                let retry = try await HTTPClient.send(request, timeout: 60, maxAttempts: 1)
                guard retry.statusCode == 200 else {
                    throw Self.openAIError(retry.statusCode, body: HTTPClient.truncate(retry.data), provider: provider)
                }
                return try Self.parseOpenAI(retry.data, model: model, provider: provider, startTime: startTime)
            }
            if case .network(let message) = error {
                throw NSError(domain: "AIEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Gagal menghubungi \(provider.rawValue): \(message)"])
            }
            if case .http(let status, let body, _) = error {
                throw Self.openAIError(status, body: body, provider: provider)
            }
            // Unreachable: ClientError only has .http and .network.
            throw Self.openAIError(-1, body: error.localizedDescription, provider: provider)
        }

        guard response.statusCode == 200 else {
            throw Self.openAIError(response.statusCode, body: HTTPClient.truncate(response.data), provider: provider)
        }
        return try Self.parseOpenAI(response.data, model: model, provider: provider, startTime: startTime)
    }

    private static func openAIError(_ status: Int, body: String, provider: AIProvider) -> NSError {
        let hint: String
        switch status {
        case 400: hint = "Permintaan ditolak — periksa model dan endpoint \(provider.rawValue). Body: \(body)"
        case 401, 403: hint = "API key tidak valid untuk \(provider.rawValue)."
        case 404: hint = "Endpoint atau model tidak ditemukan (\(provider.rawValue)). Periksa model di Pengaturan."
        case 429: hint = "Batas permintaan \(provider.rawValue) tercapai (rate limit)."
        default: hint = "\(provider.rawValue) Error: \(body)"
        }
        return NSError(domain: "AIEngine", code: status, userInfo: [NSLocalizedDescriptionKey: hint])
    }

    private static func parseOpenAI(_ data: Data, model: String, provider: AIProvider, startTime: Double) throws -> TranslationResult {
        struct OpenAIChatResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String?
                }
                let message: Message
            }
            let choices: [Choice]?
        }

        let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        guard let content = decoded.choices?.first?.message.content else {
            throw NSError(domain: "AIEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "AI tidak mengembalikan pesan."])
        }

        let name = provider == .ollama ? "Ollama (\(model))" : "AI Pro (\(model))"
        return parseJSONResult(content, engineName: name, startTime: startTime, fallbackText: content)
    }

    private static func parseJSONResult(_ rawText: String, engineName: String, startTime: Double, fallbackText: String) -> TranslationResult {
        let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

        // Clean possible markdown code fences
        var cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        struct AIOutput: Codable {
            let translation: String?
            let detected_source_language: String?
            let alternatives: [String]?
        }

        if let data = cleaned.data(using: .utf8),
           let obj = try? JSONDecoder().decode(AIOutput.self, from: data),
           let trans = obj.translation {
            return TranslationResult(
                translatedText: TextSanitizer.clean(trans),
                detectedSourceLang: obj.detected_source_language?.lowercased(),
                engine: engineName,
                alternatives: (obj.alternatives ?? []).map { TextSanitizer.clean($0) },
                latencyMs: latency
            )
        }

        // Fallback if model returned plain string
        return TranslationResult(
            translatedText: TextSanitizer.clean(fallbackText),
            detectedSourceLang: nil,
            engine: engineName,
            alternatives: [],
            latencyMs: latency
        )
    }
}
