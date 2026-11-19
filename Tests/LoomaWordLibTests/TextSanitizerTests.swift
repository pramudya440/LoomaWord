import XCTest
@testable import LoomaWordLib

final class TextSanitizerTests: XCTestCase {

    func testDecodesFullyPercentEncodedText() {
        XCTAssertEqual(TextSanitizer.clean("HELLO%20WORLD"), "HELLO WORLD")
        XCTAssertEqual(TextSanitizer.clean("100%20off"), "100 off")
    }

    func testLeavesNormalProseWithPercentUntouched() {
        // Regression: the old sanitizer rewrote "100%20off"-looking substrings inside
        // ordinary text and destroyed legitimate percent signs.
        XCTAssertEqual(TextSanitizer.clean("50% off now"), "50% off now")
        XCTAssertEqual(TextSanitizer.clean("R&D 100%"), "R&D 100%")
        XCTAssertEqual(TextSanitizer.clean("100%"), "100%")
    }

    func testMixedPercentAndSpacesIsNotDecoded() {
        XCTAssertEqual(TextSanitizer.clean("use %2C and, more"), "use %2C and, more")
    }

    func testHTMLEntityDecoding() {
        XCTAssertEqual(TextSanitizer.clean("a &amp; b"), "a & b")
        XCTAssertEqual(TextSanitizer.clean("&quot;hi&quot;"), "\"hi\"")
        XCTAssertEqual(TextSanitizer.clean("it&apos;s"), "it's")
        XCTAssertEqual(TextSanitizer.clean("5 &lt; 10 &gt; 3"), "5 < 10 > 3")
    }

    func testAmpEntityIsDecodedLast() {
        // "&amp;lt;" must become "&lt;", not "<" — otherwise double-encoded text
        // collapses one level too far.
        XCTAssertEqual(TextSanitizer.clean("&amp;lt;"), "&lt;")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(TextSanitizer.clean("  hello  "), "hello")
    }
}
