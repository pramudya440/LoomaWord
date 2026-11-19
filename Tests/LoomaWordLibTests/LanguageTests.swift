import XCTest
@testable import LoomaWordLib

final class LanguageTests: XCTestCase {

    func testFindIsCaseInsensitive() {
        XCTAssertEqual(Language.find(code: "EN")?.code, "en")
        XCTAssertEqual(Language.find(code: "zh-tw")?.code, "zh-TW")
        XCTAssertEqual(Language.find(code: "ID")?.code, "id")
    }

    func testFormalityFlagsMatchDeepLReality() {
        // DeepL does NOT support formality for these targets.
        XCTAssertEqual(Language.find(code: "id")?.supportsFormality, false)
        XCTAssertEqual(Language.find(code: "ko")?.supportsFormality, false)
        XCTAssertEqual(Language.find(code: "zh")?.supportsFormality, false)
        // DeepL does support them here.
        XCTAssertEqual(Language.find(code: "de")?.supportsFormality, true)
        XCTAssertEqual(Language.find(code: "fr")?.supportsFormality, true)
        XCTAssertEqual(Language.find(code: "ja")?.supportsFormality, true)
        XCTAssertEqual(Language.find(code: "vi")?.supportsFormality, true)
    }

    func testEveryLanguageHasUniqueCode() {
        let codes = Language.allLanguages.map { $0.code.lowercased() }
        XCTAssertEqual(codes.count, Set(codes).count)
    }

    func testAutoIsNeverAFormalityTarget() {
        XCTAssertFalse(Language.auto.supportsFormality)
    }
}
