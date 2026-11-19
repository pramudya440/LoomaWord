import XCTest
@testable import LoomaWordLib

final class URLBuildingTests: XCTestCase {

    func testGoogleURLEscapesReservedCharacters() throws {
        let url = try XCTUnwrap(FastEngine.googleURL(text: "R&D C++ 100% fun?", sourceLang: "auto", targetLang: "id"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = try XCTUnwrap(components.queryItems)

        // `+` must be escaped: servers read a literal `+` as a space.
        XCTAssertFalse(url.absoluteString.contains("C++"), "plus signs must be percent-encoded")
        XCTAssertTrue(url.absoluteString.contains("C%2B%2B"))
        XCTAssertTrue(url.absoluteString.contains("R%26D"))

        let q = items.first { $0.name == "q" }?.value
        XCTAssertEqual(q, "R&D C++ 100% fun?")
    }

    func testGoogleURLKeepsLanguageParams() throws {
        let url = try XCTUnwrap(FastEngine.googleURL(text: "hi", sourceLang: "en", targetLang: "id"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "sl" }?.value, "en")
        XCTAssertEqual(items.first { $0.name == "tl" }?.value, "id")
    }

    func testMyMemoryUsesAutodetectForAutoSource() throws {
        let url = try XCTUnwrap(FastEngine.myMemoryURL(text: "hello", sourceLang: "auto", targetLang: "id"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        // MyMemory rejects "auto" as a source language.
        XCTAssertEqual(items.first { $0.name == "langpair" }?.value, "Autodetect|id")
    }

    func testMyMemoryKeepsExplicitSource() throws {
        let url = try XCTUnwrap(FastEngine.myMemoryURL(text: "hello", sourceLang: "en", targetLang: "id"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "langpair" }?.value, "en|id")
    }
}
