import XCTest
@testable import LoomaWordLib

final class DeepLEngineTests: XCTestCase {

    // MARK: - Target language mapping

    func testTargetLanguageMapping() {
        XCTAssertEqual(DeepLEngine.deepLTargetCode("en"), "EN")
        XCTAssertEqual(DeepLEngine.deepLTargetCode("id"), "ID")
        XCTAssertEqual(DeepLEngine.deepLTargetCode("pt"), "PT")
        // DeepL wants ZH-HANT, never ZH-TW.
        XCTAssertEqual(DeepLEngine.deepLTargetCode("zh-TW"), "ZH-HANT")
        XCTAssertEqual(DeepLEngine.deepLTargetCode("zh"), "ZH")
    }

    func testUnsupportedTargetsReturnNil() {
        XCTAssertNil(DeepLEngine.deepLTargetCode("th"), "Thai is not a DeepL target")
        XCTAssertNil(DeepLEngine.deepLTargetCode("hi"), "Hindi is not a DeepL target")
        XCTAssertNil(DeepLEngine.deepLTargetCode("auto"), "auto is source-only")
    }

    // MARK: - Formality

    func testStandardToneSendsNoFormality() {
        // Regression: sending formality=default to Indonesian always failed with
        // "'formality' is not supported for given 'target_lang'".
        XCTAssertNil(DeepLEngine.formalityParameter(tone: .standard, targetLang: "id"))
        XCTAssertNil(DeepLEngine.formalityParameter(tone: .standard, targetLang: "en"))
    }

    func testFormalTonesUsePreferMore() {
        XCTAssertEqual(DeepLEngine.formalityParameter(tone: .formal, targetLang: "de"), "prefer_more")
        XCTAssertEqual(DeepLEngine.formalityParameter(tone: .business, targetLang: "de"), "prefer_more")
        XCTAssertEqual(DeepLEngine.formalityParameter(tone: .academic, targetLang: "fr"), "prefer_more")
        // prefer_more/prefer_less are accepted for ALL targets, including Indonesian.
        XCTAssertEqual(DeepLEngine.formalityParameter(tone: .formal, targetLang: "id"), "prefer_more")
    }

    func testInformalTonesUsePreferLess() {
        XCTAssertEqual(DeepLEngine.formalityParameter(tone: .informal, targetLang: "id"), "prefer_less")
        XCTAssertEqual(DeepLEngine.formalityParameter(tone: .creative, targetLang: "id"), "prefer_less")
    }

    // MARK: - Request body

    func testBuildBodyOmitsFormalityForStandard() {
        let body = DeepLEngine.buildBody(text: "halo", sourceLang: "en", targetLang: "ID", tone: .standard)
        XCTAssertEqual(body["target_lang"] as? String, "ID")
        XCTAssertEqual(body["source_lang"] as? String, "EN")
        XCTAssertNil(body["formality"])
    }

    func testBuildBodyOmitsSourceForAuto() {
        let body = DeepLEngine.buildBody(text: "halo", sourceLang: "auto", targetLang: "EN", tone: .standard)
        XCTAssertNil(body["source_lang"])
    }

    func testBuildBodyIncludesFormalityWhenRequested() {
        let body = DeepLEngine.buildBody(text: "halo", sourceLang: "auto", targetLang: "DE", tone: .formal)
        XCTAssertEqual(body["formality"] as? String, "prefer_more")
    }

    // MARK: - Endpoint & label

    func testEndpointSelection() {
        XCTAssertEqual(DeepLEngine.endpoint(isPro: false, authKey: "abc:fx", customEndpoint: nil), "https://api-free.deepl.com/v2/translate")
        XCTAssertEqual(DeepLEngine.endpoint(isPro: false, authKey: "abc", customEndpoint: nil), "https://api.deepl.com/v2/translate")
        XCTAssertEqual(DeepLEngine.endpoint(isPro: true, authKey: "abc:fx", customEndpoint: nil), "https://api.deepl.com/v2/translate")
        XCTAssertEqual(DeepLEngine.endpoint(isPro: false, authKey: "abc", customEndpoint: "http://localhost:8080"), "http://localhost:8080")
    }

    func testEngineLabelMatchesPlan() {
        XCTAssertEqual(DeepLEngine.engineLabel(isPro: true), "DeepL Pro")
        // Regression: free keys used to be labelled "DeepL Pro".
        XCTAssertEqual(DeepLEngine.engineLabel(isPro: false), "DeepL Free")
    }
}
