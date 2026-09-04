import Foundation
import SwiftLintCore

/// A document says what is, so a negation in its own voice is a sentence waiting to be turned around.
/// Code, quoted specimens, links and addresses are the document showing something rather than saying it,
/// so they stay out of the check.
///
/// Ported from tienda-ios's `DocumentationContractTests.testTheDocumentsSayWhatIs`.
struct DocumentSaysWhatIsRule: DocumentRule, OptInRule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "document_says_what_is",
        name: "Document Says What Is",
        description: """
            A document says what is, so a negation in its own voice is a sentence waiting to be turned \
            around — state the positive core instead
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "The linter runs on every push.",
            "`not`, `no` and `never` are fine inside code.",
            "[Nothing to see here](https://example.com/not-a-real-page)",
        ]),
        triggeringExamples: #examples([
            "This ↓never fails.",
            "There is ↓no reason to wait.",
        ])
    )

    private static let negations = ["not", "no", "none", "never", "cannot", "neither", "nor", "nothing"]

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        guard configuration.scope.contains(file) else {
            return []
        }
        let voice = DocumentVoice.ownVoice(of: file.contents)
        let lines = voice.split(separator: "\n", omittingEmptySubsequences: false)

        return lines.enumerated().flatMap { offset, line -> [StyleViolation] in
            Self.negations
                .filter { line.range(of: "\\b\($0)\\b", options: [.regularExpression, .caseInsensitive]) != nil }
                .map { word in
                    StyleViolation(
                        ruleDescription: Self.description,
                        severity: configuration.severity,
                        location: Location(file: file.path, line: offset + 1, character: 1),
                        reason: "Says \"\(word)\" — state the positive core instead of what isn't true"
                    )
                }
        }
    }
}
