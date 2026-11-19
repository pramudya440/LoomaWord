import XCTest
@testable import LoomaWordLib

final class SettingsDecodingTests: XCTestCase {

    func testDecodesLegacyFileWithoutNewFields() throws {
        // A settings.json written before `showMenuBarIcon` existed (this exact shape
        // caused a real settings reset in commit 2e13899).
        let legacy = """
        {"preferredEngine":"DeepL API","deepLAuthKey":"secret-key","aiProvider":"Google Gemini","aiModel":"gemini-1.5-flash"}
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: legacy)
        XCTAssertEqual(settings.preferredEngine, .deepL)
        XCTAssertEqual(settings.deepLAuthKey, "secret-key", "stored API keys must survive a schema change")
        XCTAssertEqual(settings.aiProvider, .gemini)
        XCTAssertTrue(settings.showMenuBarIcon, "missing key must fall back to the default")
    }

    func testMigratesRetiredGeminiModel() throws {
        let json = #"{"aiProvider":"Google Gemini","aiModel":"gemini-1.5-flash"}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(settings.aiModel, AIProvider.gemini.defaultModel)
        XCTAssertFalse(AIProvider.retiredModels.contains(settings.aiModel))
    }

    func testFillsOllamaEndpointWhenEmpty() throws {
        let json = #"{"aiProvider":"Ollama (Local)","aiEndpoint":""}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(settings.aiEndpoint, AIProvider.ollama.defaultEndpoint)
    }

    func testUnknownEnumValueFallsBackToDefault() throws {
        let json = #"{"preferredEngine":"Nonexistent Engine","selectedTone":"Shouty"}"#.data(using: .utf8)!
        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(settings.preferredEngine, .smart)
        XCTAssertEqual(settings.selectedTone, .standard)
    }

    func testRoundTripPreservesValues() throws {
        var settings = AppSettings()
        settings.deepLAuthKey = "my-key"
        settings.aiProvider = .openai
        settings.aiModel = "gpt-6-luna"
        settings.showMenuBarIcon = false

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
    }

    func testDefaultModelsAreNotRetired() {
        for provider in AIProvider.allCases {
            XCTAssertFalse(
                AIProvider.retiredModels.contains(provider.defaultModel),
                "\(provider.rawValue) default model is retired"
            )
        }
    }
}
