import Foundation

/// Splits large texts into provider-friendly pieces.
///
/// Pure and dependency-free so it can be unit tested and reused outside the
/// main-actor coordinator.
public enum TextChunker {

    /// Split text into chunks of at most `maxChars`, preferring paragraph > sentence >
    /// word boundaries so meaning isn't cut mid-clause. Never returns an empty array
    /// for non-empty input, and always terminates (no zero-length cuts).
    public static func chunk(_ text: String, maxChars: Int) -> [String] {
        guard maxChars > 0, text.count > maxChars else { return [text] }

        var chunks: [String] = []
        var remaining = text
        while !remaining.isEmpty {
            if remaining.count <= maxChars {
                chunks.append(remaining)
                break
            }
            let head = remaining.prefix(maxChars)
            var cutIndex = head.endIndex

            if let paragraph = head.range(of: "\n\n", options: .backwards), paragraph.upperBound > head.startIndex {
                cutIndex = paragraph.upperBound
            } else if let newline = head.lastIndex(of: "\n"), newline > remaining.startIndex {
                cutIndex = newline
            } else if let sentenceEnd = head.lastIndex(where: { ".!?。！？".contains($0) }), head.index(after: sentenceEnd) > remaining.startIndex {
                cutIndex = head.index(after: sentenceEnd)
            } else if let space = head.lastIndex(of: " "), space > remaining.startIndex {
                cutIndex = space
            }
            // Safety: never cut at the very start or we would loop forever.
            if cutIndex <= remaining.startIndex {
                cutIndex = head.endIndex
            }

            // cutIndex is the start of the *next* chunk: take [start, cutIndex).
            // (`prefix(through:)` would be inclusive and duplicate one character.)
            let piece = remaining[..<cutIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { chunks.append(piece) }
            remaining = String(remaining[cutIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return chunks.isEmpty ? [text] : chunks
    }
}
