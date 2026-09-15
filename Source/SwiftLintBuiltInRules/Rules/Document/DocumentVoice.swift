import Foundation

/// Blanks out the parts of a document that show something rather than say it — code, quotes, links,
/// addresses — so a voice check reads only what the document asserts in its own words.
///
/// Ported from tienda-ios's `DocumentationContractTests.ownVoice(of:)`, which proved this pattern against
/// a real doc set's false positives.
enum DocumentVoice {
    static func ownVoice(of text: String) -> String {
        let specimens = [
            "```[\\s\\S]*?```", // fenced code
            "(?m)^(?:[ ]{4,}|\\t).*$", // indented code
            "`[^`]*`", // inline code
            "[\"\u{201C}][^\"\u{201D}]{0,200}[\"\u{201D}]", // a quoted example, wrapped across lines or on one
            "\\]\\([^)]*\\)", // a link's target
            "https?://\\S+|\\S+@\\S+", // addresses
        ]
        return specimens.reduce(text) { voice, pattern in blanking(pattern, in: voice) }
    }

    private static func blanking(_ pattern: String, in text: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        var characters = Array(text)
        for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.distance(from: text.startIndex, to: range.upperBound)
            for index in start..<end where characters[index] != "\n" {
                characters[index] = " "
            }
        }
        return String(characters)
    }
}
