import Foundation

/// Single shared cleanup pass for text returned by translation providers.
///
/// Rules:
/// - HTML entities are decoded once, here. `&amp;` is decoded **last** so that a literal
///   `&amp;` in the source text survives (`&amp;amp;` → `&amp;`, not `&`).
/// - Percent-decoding is all-or-nothing: only applied when the string contains at least one
///   well-formed `%XX` sequence *and* no literal spaces. A result with literal spaces is
///   already human text (`"50% off"`), so decoding would corrupt it (`"100%20off"` →
///   `"100 off"` only happens when the whole string looks percent-encoded).
///
/// Engines must not run their own copy of this logic.
public enum TextSanitizer {

    public static func clean(_ input: String) -> String {
        let percentDecoded = decodePercentEncoding(input)
        return decodeHTMLEntities(percentDecoded)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Decode `%XX` sequences only when the string looks fully percent-encoded.
    public static func decodePercentEncoding(_ text: String) -> String {
        guard text.contains("%") else { return text }
        // Literal spaces mean this is normal prose with a percent sign in it.
        if text.contains(" ") { return text }
        guard text.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression) != nil else { return text }
        return text.removingPercentEncoding ?? text
    }

    /// Decode the common HTML entities providers occasionally emit.
    /// Order matters: `&amp;` must be last or `&amp;lt;` collapses to `<`.
    public static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#34;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        return result
    }
}
