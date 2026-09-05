import Foundation
import SourceKittenFramework
import SwiftIDEUtils
import SwiftLintCore

struct CommentAddsNoWordRule: SourceKitFreeRule, OptInRule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "comment_adds_no_word",
        name: "Comment Adds No Word",
        description: """
            Every word in this comment is already in the code beneath it, so a reader who reads the code \
            learns nothing from reading the comment first. Delete it, and keep the comments that carry a \
            word the code cannot: a fact about another system, a reason, a warning about what looks like \
            a mistake
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            """
            // Django rejects a path without a trailing slash
            components.path += "/"
            """,
            """
            // Set to ambient so other apps keep playing
            try session.setCategory(.ambient)
            """,
            """
            /// The session the dinner builder opened with, which the server mints per launch.
            private let dinnerBuilderSessionId: String
            """,
            """
            // TODO: Remove once the gateway stops answering a committed DELETE with a 502.
            func delete() {}
            """,
            "// https://github.com/kolonialno/iglu-schema-registry/blob/main/schemas/com.oda/device_context",
            """
            // Mode to determine whether to allow refresh control
            let refreshControlMode: RefreshControlMode
            """,
            """
            /// Update an existing user delivery address
            func updateUserDeliveryAddress(_ address: UserDeliveryAddressUpdateModel) async throws
            """,
        ]),
        triggeringExamples: #examples([
            """
            ↓// Session id for the dinner builder
            private let dinnerBuilderSessionId: String
            """,
            """
            ↓// Name of the list
            private let listName: String
            """,
            """
            ↓// Our unique device identifier
            static let uniqueVendorIdentifier = UIDevice.current.identifierForVendor?.uuidString ?? ""
            """,
            """
            ↓// Placeholder of the input field
            @Published var placeholderText: String = L10n.DeliveryOptions.InputField.placeholder
            """,
        ])
    )

    func validate(file: SwiftLintFile) -> [StyleViolation] {
        let commentLines = file.commentLineIndices
        guard commentLines.isNotEmpty else {
            return []
        }
        let lines = file.lines
        var violations: [StyleViolation] = []

        for block in commentLines.consecutiveRuns {
            guard let first = block.first, let last = block.last, last + 1 < lines.count else {
                continue
            }
            let body = block
                .compactMap { lines[$0].content.commentBody }
                .joined(separator: " ")
            guard body.carriesWords else {
                continue
            }
            var position = last + 1
            while position < lines.count, commentLines.contains(position)
                || lines[position].content.isLintDirective || !lines[position].content.isNotBlank {
                position += 1
            }
            guard position < lines.count else {
                continue
            }
            let code = lines[position]
            let words = body.contentWords
            guard words.isNotEmpty, words.isSubset(of: code.content.contentWords) else {
                continue
            }
            violations.append(
                StyleViolation(
                    ruleDescription: Self.description,
                    severity: configuration.severity,
                    location: Location(file: file, characterOffset: lines[first].range.location)
                )
            )
        }
        return violations
    }
}

private extension SwiftLintFile {
    /// Positions in `lines`, not `Line.index`. A line spelled as a comment is one, unless a string literal
    /// or a block comment encloses it — the classifier answers only that, since its byte offsets start a
    /// line early.
    var commentLineIndices: Set<Int> {
        let quoted = syntaxClassifications
            .filter { $0.kind == .stringLiteral || $0.kind == .blockComment || $0.kind == .docBlockComment }
            .map { $0.range.toSourceKittenByteRange() }
        var indices = Set<Int>()
        for (position, line) in lines.enumerated()
        where line.content.isCommentLine && !line.content.isLintDirective {
            let isQuoted = quoted.contains {
                $0.location < line.byteRange.upperBound && line.byteRange.location < $0.upperBound
            }
            if !isQuoted {
                indices.insert(position)
            }
        }
        return indices
    }
}

private extension Set<Int> {
    /// Comment lines grouped into blocks of adjacent lines, each block read as one comment.
    var consecutiveRuns: [[Int]] {
        sorted().reduce(into: [[Int]]()) { runs, line in
            if var last = runs.last, last.last == line - 1 {
                last.append(line)
                runs[runs.count - 1] = last
            } else {
                runs.append([line])
            }
        }
    }
}

private extension String {
    var isNotBlank: Bool { !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var isCommentLine: Bool { trimmingCharacters(in: .whitespaces).hasPrefix("//") }

    var isLintDirective: Bool { contains("swiftlint:") || contains("oida:") }

    var commentBody: String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("//") else {
            return nil
        }
        return String(trimmed.drop(while: { $0 == "/" }))
    }

    /// Comments the rule refuses to judge: markers carrying intent, directives, and bare links.
    var carriesWords: Bool {
        let body = trimmingCharacters(in: .whitespaces)
        guard body.isNotBlank, !body.contains("://") else {
            return false
        }
        let markers = ["TODO", "FIXME", "MARK", "swiftlint:", "oida:", "- Parameter", "- Returns"]
        return !markers.contains { body.contains($0) }
    }

    var contentWords: Set<String> {
        var words = Set<String>()
        for token in split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "_" }) {
            for word in String(token).splitBeforeCapitals where word.count > 1 {
                let lowered = word.lowercased()
                if !Self.ignoredWords.contains(lowered) {
                    words.insert(lowered)
                }
            }
        }
        return words
    }

    /// Words of an identifier, splitting an acronym from what follows it: `UIDevice` is `UI` and `Device`.
    var splitBeforeCapitals: [String] {
        let characters = Array(self)
        var words: [String] = []
        for (offset, character) in characters.enumerated() {
            let previous = offset > 0 ? characters[offset - 1] : nil
            let next = offset + 1 < characters.count ? characters[offset + 1] : nil
            let startsWord = character.isUppercase
                && (previous?.isLowercase == true || previous?.isNumber == true || next?.isLowercase == true)
            if words.isEmpty || startsWord {
                words.append(String(character))
            } else {
                words[words.count - 1].append(character)
            }
        }
        return words
    }

    static let ignoredWords: Set<String> = [
        "of", "in", "to", "is", "it", "or", "if", "at", "by", "on", "an", "as", "be", "do", "no", "so",
        "we", "us", "my", "up", "he", "me", "am", "are", "was", "were",
        "the", "this", "that", "these", "those", "its", "our", "your", "their",
        "for", "with", "and", "but", "not", "you", "they", "them", "has", "have", "had",
        "when", "while", "which", "who", "what", "how", "then", "than", "there", "here", "all", "any",
        "some", "each", "other", "more", "most", "only", "just", "also", "very", "such", "via", "per",
    ]
}
