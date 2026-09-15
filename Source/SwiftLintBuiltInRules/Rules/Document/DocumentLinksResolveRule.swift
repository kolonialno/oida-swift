import Foundation
import SwiftLintCore

/// A relative link in a document is a promise the target still exists. Resolved against the directory the
/// document sits in, which is where following the link lands a reader and how GitHub renders it. A document
/// with no path on disk falls back to the directory oida runs from, since there is nothing else to go on.
///
/// Ported from tienda-ios's `DocumentationContractTests.testEveryLinkInADocumentResolves`.
struct DocumentLinksResolveRule: DocumentRule, OptInRule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "document_links_resolve",
        name: "Document Links Resolve",
        description: "A relative link outlives the file it once pointed to, so a reader follows it into nothing",
        kind: .lint,
        nonTriggeringExamples: #examples([
            "[External](https://example.com/anything)",
            "[Skip ahead](#a-heading)",
        ]),
        triggeringExamples: #examples([
            "[See the ↓guidelines](path/that/does-not-exist.md)",
        ])
    )

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        guard configuration.scope.contains(file) else {
            return []
        }
        let text = file.contents
        let base = file.path?.deletingLastPathComponent() ?? URL.cwd
        let matches = regex("\\]\\(([^)]+)\\)").matches(in: text, range: NSRange(text.startIndex..., in: text))

        return matches.compactMap { match -> StyleViolation? in
            guard let targetRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            let target = String(text[targetRange])
            guard !target.hasPrefix("http"), !target.hasPrefix("mailto:"), !target.hasPrefix("#") else {
                return nil
            }
            let path = target.split(separator: "#").first.map(String.init) ?? target
            guard !FileManager.default.fileExists(atPath: base.appending(path: path).standardized.path) else {
                return nil
            }

            let line = text.distance(from: text.startIndex, to: targetRange.lowerBound, countingOccurrencesOf: "\n")
            return StyleViolation(
                ruleDescription: Self.description,
                severity: configuration.severity,
                location: Location(file: file.path, line: line + 1, character: 1),
                reason: "Links to \(target), which is missing"
            )
        }
    }
}

private extension String {
    func distance(from start: Index, to end: Index, countingOccurrencesOf character: Character) -> Int {
        self[start..<end].filter { $0 == character }.count
    }
}
