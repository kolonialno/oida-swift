import Foundation
import SourceKittenFramework
import SwiftIDEUtils
import SwiftLintCore

struct NoMarkCommentsRule: SourceKitFreeRule, OptInRule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "no_mark_comments",
        name: "No MARK Comments",
        description: """
            A banner names a section the declarations below it already name, and it is maintained by hand \
            while everything around it moves. Xcode's jump bar reads them, so this is a decision rather \
            than a reading of the field — Airbnb's style guide requires a MARK above every type and \
            Google's endorses them for grouping. A file needing section headers to be navigable is a file \
            to split, and `--fix` deletes the line
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "// A note about the code below",
            """
            /// The identifier the server issues.
            let id: String
            """,
            #"let text = "// MARK: - inside a string literal""#,
        ]),
        triggeringExamples: #examples([
            "↓// MARK: - Helpers",
            "↓// MARK: Lifecycle",
            """
            struct Cart {
                ↓// MARK: - Private
                private func empty() {}
            }
            """,
        ])
    )

    func violationRanges(in file: SwiftLintFile) -> [NSRange] {
        file.syntaxClassifications
            .filter(\.kind.isComment)
            .compactMap { classification in
                let byteRange = classification.range.toSourceKittenByteRange()
                guard let body = file.stringView.substringWithByteRange(byteRange), body.isMarkBanner else {
                    return nil
                }
                return file.stringView.byteRangeToNSRange(byteRange)
            }
    }

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        violationRanges(in: file).map { range in
            StyleViolation(
                ruleDescription: Self.description,
                severity: configuration.severity,
                location: Location(file: file, characterOffset: range.location)
            )
        }
    }
}

private extension String {
    var isMarkBanner: Bool {
        let body = trimmingCharacters(in: .whitespaces)
        guard body.hasPrefix("//") else {
            return false
        }
        return body.dropFirst(2).trimmingCharacters(in: CharacterSet(charactersIn: "/ -")).hasPrefix("MARK")
    }
}
