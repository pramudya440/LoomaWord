import XCTest
@testable import LoomaWordLib

final class TextChunkerTests: XCTestCase {

    func testShortTextIsSingleChunk() {
        XCTAssertEqual(TextChunker.chunk("hello world", maxChars: 100), ["hello world"])
    }

    func testLongTextSplitsOnParagraphs() {
        let text = Array(repeating: "Ini adalah paragraf yang cukup panjang untuk dipecah.", count: 40)
            .joined(separator: "\n\n")
        let chunks = TextChunker.chunk(text, maxChars: 200)

        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 200)
        }
        XCTAssertTrue(chunks.joined(separator: " ").contains("paragraf yang cukup panjang"))
    }

    func testChunkNeverLoopsOnLeadingNewline() {
        let text = "\n" + String(repeating: "a", count: 500)
        let chunks = TextChunker.chunk(text, maxChars: 50)
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertEqual(chunks.joined().filter { $0 == "a" }.count, 500)
    }

    func testChunkHandlesUnbrokenLongWord() {
        let text = String(repeating: "x", count: 500)
        let chunks = TextChunker.chunk(text, maxChars: 100)
        XCTAssertEqual(chunks.count, 5)
        XCTAssertEqual(chunks.joined(), text)
    }

    func testChunkRespectsSentenceBoundaries() {
        let text = "Kalimat pertama. Kalimat kedua. " + String(repeating: "padatan ", count: 50)
        let chunks = TextChunker.chunk(text, maxChars: 40)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 40)
        }
    }

    func testEmptyAndZeroLimits() {
        XCTAssertEqual(TextChunker.chunk("", maxChars: 10), [""])
        XCTAssertEqual(TextChunker.chunk("abc", maxChars: 0), ["abc"])
    }
}
