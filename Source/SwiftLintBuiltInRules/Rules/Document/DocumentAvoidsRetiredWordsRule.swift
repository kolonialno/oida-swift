import Foundation
import SwiftLintCore

/// A word joins this list once a document reads better without it, by reading rather than by argument —
/// say what the thing does instead of reaching for a word that promises it.
///
/// Ported from tienda-ios's `DocumentationContractTests.testTheDocumentsAvoidTheWordsVoiceRetires`.
struct DocumentAvoidsRetiredWordsRule: DocumentRule, OptInRule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "document_avoids_retired_words",
        name: "Document Avoids Retired Words",
        description: "A retired word promises what a plain description of the thing already shows",
        kind: .lint,
        nonTriggeringExamples: #examples([
            "This retries automatically on failure.",
        ]),
        triggeringExamples: #examples([
            "This will ↓leverage the cache.",
            "A ↓seamless upgrade path.",
        ])
    )

    private static let retired = [
        "leverage",
        "seamless",
        "robust",
        "powerful",
        "simply",
        "in order to",
        "lives at the edge",
    ]

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        guard configuration.scope.contains(file) else {
            return []
        }
        let lines = file.contents.split(separator: "\n", omittingEmptySubsequences: false)

        return lines.enumerated().flatMap { offset, line -> [StyleViolation] in
            Self.retired
                .filter { line.range(of: "\\b\($0)\\b", options: [.regularExpression, .caseInsensitive]) != nil }
                .map { word in
                    StyleViolation(
                        ruleDescription: Self.description,
                        severity: configuration.severity,
                        location: Location(file: file.path, line: offset + 1, character: 1),
                        reason: "Uses \"\(word)\" — say what the thing does instead"
                    )
                }
        }
    }
}
