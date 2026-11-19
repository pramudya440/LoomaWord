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

        // Filter active glossary entries
        let activeGlossary = glossary.filter { $0.isEnabled && !$0.sourceTerm.isEmpty && !$0.targetTerm.isEmpty }
        var glossaryRule = ""
        if !activeGlossary.isEmpty {
            let terms = activeGlossary.map { "- '\($0.sourceTerm)' must be translated as '\($0.targetTerm)'" }.joined(separator: "\n")
            glossaryRule = "\n\nStrict Glossary Rules:\n\(terms)"
        }

        let systemPrompt = """
        You are LoomaWord AI, a world-class translation engine and professional linguist.
        Translate the provided text from \(srcName) to \(tgtName).
        
        Tone/Style Specification:
        \(tone.promptInstruction)
        \(glossaryRule)
        
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

        switch provider {
        case .gemini:
            return try await translateGemini(
                text: text,
                systemPrompt: systemPrompt,
                apiKey: apiKey,
                model: model.isEmpty ? "gemini-1.5-flash" : model,
                startTime: startTime
            )
        case .openai, .ollama, .custom:
            return try await translateOpenAICompatible(
                text: text,
                systemPrompt: systemPrompt,
                provider: provider,
                apiKey: apiKey,
                model: model,
                customEndpoint: customEndpoint,
                startTime: startTime
            )
        }
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

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)"
        guard let url = URL(string: endpoint) else {
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

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AIEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Respons server tidak valid."])
        }

        if http.statusCode != 200 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "AIEngine", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini Error: \(msg)"])
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

        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let jsonText = decoded.candidates?.first?.content.parts.first?.text else {
            throw NSError(domain: "AIEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Gemini tidak mengembalikan teks jawaban."])
        }

        return parseJSONResult(jsonText, engineName: "Gemini (\(model))", startTime: startTime, fallbackText: jsonText)
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
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let chosenModel = model.isEmpty ? provider.defaultModel : model

        let payload: [String: Any] = [
            "model": chosenModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.2,
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "AIEngine", code: 500, userInfo: [NSLocalizedDescriptionKey: "Respons jaringan tidak valid."])
        }

        if http.statusCode != 200 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NSError(domain: "AIEngine", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "AI Server Error: \(msg)"])
        }

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

        let name = provider == .ollama ? "Ollama (\(chosenModel))" : "AI Pro (\(chosenModel))"
        return parseJSONResult(content, engineName: name, startTime: startTime, fallbackText: content)
    }

    private func parseJSONResult(_ rawText: String, engineName: String, startTime: Double, fallbackText: String) -> TranslationResult {
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
                translatedText: trans,
                detectedSourceLang: obj.detected_source_language?.lowercased(),
                engine: engineName,
                alternatives: obj.alternatives ?? [],
                latencyMs: latency
            )
        }

        // Fallback if model returned plain string
        return TranslationResult(
            translatedText: fallbackText.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedSourceLang: nil,
            engine: engineName,
            alternatives: [],
            latencyMs: latency
        )
    }
}
