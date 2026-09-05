import Foundation
import SourceKittenFramework
import SwiftIDEUtils
import SwiftLintCore

struct NoMarkCommentsRule: SourceKitFreeRule, SubstitutionCorrectableRule, OptInRule {
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
        ]),
        corrections: #corrections([
            """
            // MARK: - Helpers
            func total() {}
            """: """
            func total() {}
            """,
            """
            struct Cart {
                // MARK: - Private
                private func empty() {}
            }
            """: """
            struct Cart {
                private func empty() {}
            }
            """,
            """
            func total() {}

            // MARK: - Helpers

            func helper() {}
            """: """
            func total() {}

            func helper() {}
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

    func substitution(for violationRange: NSRange, in file: SwiftLintFile) -> (NSRange, String)? {
        let contents = file.contents.bridge()
        func isBlankLine(containing location: Int) -> Bool {
            let range = contents.lineRange(for: NSRange(location: location, length: 0))
            return contents.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        let lineRange = contents.lineRange(for: violationRange)
        guard contents.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines).isMarkBanner
        else {
            return (violationRange, "")
        }
        // A banner between two blank lines leaves both behind, so it takes the one below it with it.
        guard lineRange.location > 0, lineRange.upperBound < contents.length,
            isBlankLine(containing: lineRange.location - 1), isBlankLine(containing: lineRange.upperBound)
        else {
            return (lineRange, "")
        }
        let following = contents.lineRange(for: NSRange(location: lineRange.upperBound, length: 0))
        return (NSRange(location: lineRange.location, length: lineRange.length + following.length), "")
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
