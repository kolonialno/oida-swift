import Foundation
import SourceKittenFramework
import SwiftIDEUtils
import SwiftLintCore

struct NoDocCommentsRule: SourceKitFreeRule, OptInRule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "no_doc_comments",
        name: "No Doc Comments",
        description: """
            A doc comment's job is to describe the declaration it sits on, which is restatement by \
            purpose, and the ones that carry something the code cannot say read exactly like the ones \
            that do not — same length, same shape, same position. Since a parser cannot tell them apart, \
            this cuts all of them rather than none. Say it in the type's name, in a test, or in the pull \
            request. An ordinary `//` comment is left alone: those are mostly the notes that stop someone \
            deleting code that only looks wrong
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            """
            // Django rejects a path without a trailing slash
            components.path += "/"
            """,
            """
            // The tap layer is invisible on purpose; the row below it swallows touches without it.
            .overlay(Color.black.opacity(0.0000001))
            """,
            "let text = \"/// not a comment\"",
        ]),
        triggeringExamples: #examples([
            """
            ↓/// The order a shopper is buying again.
            struct LastOrder {}
            """,
            """
            struct Cart {
                ↓/// Session id for the dinner builder
                private let dinnerBuilderSessionId: String
            }
            """,
            """
            ↓/**
             The standard client for this process.
             */
            let client = Client()
            """,
        ])
    )

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        file.syntaxClassifications
            .filter { $0.kind == .docLineComment || $0.kind == .docBlockComment }
            .compactMap { classification in
                let byteRange = classification.range.toSourceKittenByteRange()
                guard let range = file.stringView.byteRangeToNSRange(byteRange) else {
                    return nil
                }
                return StyleViolation(
                    ruleDescription: Self.description,
                    severity: configuration.severity,
                    location: Location(file: file, characterOffset: range.location)
                )
            }
    }
}
