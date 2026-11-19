import XCTest
@testable import LoomaWordLib

@MainActor
final class CoordinatorLogicTests: XCTestCase {

    // MARK: - Cache key

    func testCacheKeyChangesWithToneAndLanguages() {
        let settings = AppSettings()
        let base = TranslationCoordinator.cacheKey(
            text: "halo", source: "en", target: "id",
            engine: .deepL, tone: .standard, settings: settings, glossary: []
        )
        let otherTone = TranslationCoordinator.cacheKey(
            text: "halo", source: "en", target: "id",
            engine: .deepL, tone: .formal, settings: settings, glossary: []
        )
        let otherLang = TranslationCoordinator.cacheKey(
            text: "halo", source: "en", target: "ja",
            engine: .deepL, tone: .standard, settings: settings, glossary: []
        )
        XCTAssertNotEqual(base, otherTone)
        XCTAssertNotEqual(base, otherLang)

        let same = TranslationCoordinator.cacheKey(
            text: "halo", source: "en", target: "id",
            engine: .deepL, tone: .standard, settings: settings, glossary: []
        )
        XCTAssertEqual(base, same)

        // Glossary edits must invalidate the cache.
        let glossary = [GlossaryItem(sourceTerm: "bug", targetTerm: "kutu", sourceLang: "en", targetLang: "id")]
        let withGlossary = TranslationCoordinator.cacheKey(
            text: "halo", source: "en", target: "id",
            engine: .deepL, tone: .standard, settings: settings, glossary: glossary
        )
        XCTAssertNotEqual(base, withGlossary)
    }

    func testCacheKeyDistinguishesEnginesAndModels() {
        let settings = AppSettings()
        let ai = TranslationCoordinator.cacheKey(
            text: "halo", source: "en", target: "id",
            engine: .ai, tone: .standard, settings: settings, glossary: []
        )
        let fast = TranslationCoordinator.cacheKey(
            text: "halo", source: "en", target: "id",
            engine: .fast, tone: .standard, settings: settings, glossary: []
        )
        XCTAssertNotEqual(ai, fast)
    }

    // MARK: - AI glossary filtering

    func testGlossaryOnlyAppliesToMatchingLanguagePair() {
        let enId = GlossaryItem(sourceTerm: "bug", targetTerm: "kutu", sourceLang: "en", targetLang: "id")
        let jaEn = GlossaryItem(sourceTerm: "木", targetTerm: "tree", sourceLang: "ja", targetLang: "en")
        let glossary = [enId, jaEn]

        let forEnId = AIEngine.glossaryRule(glossary, sourceLang: "en", targetLang: "id")
        XCTAssertTrue(forEnId.contains("bug"))
        XCTAssertFalse(forEnId.contains("木"))

        let forJaEn = AIEngine.glossaryRule(glossary, sourceLang: "ja", targetLang: "en")
        XCTAssertTrue(forJaEn.contains("木"))
        XCTAssertFalse(forJaEn.contains("bug"))
    }

    func testDisabledGlossaryEntriesAreIgnored() {
        var item = GlossaryItem(sourceTerm: "bug", targetTerm: "kutu", sourceLang: "en", targetLang: "id")
        item.isEnabled = false
        XCTAssertEqual(AIEngine.glossaryRule([item], sourceLang: "en", targetLang: "id"), "")
    }

    func testEmptyGlossaryProducesNoRule() {
        XCTAssertEqual(AIEngine.glossaryRule([], sourceLang: "en", targetLang: "id"), "")
    }
}
