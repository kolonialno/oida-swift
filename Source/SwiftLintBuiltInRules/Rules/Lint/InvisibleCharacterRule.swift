import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(correctable: true)
struct InvisibleCharacterRule: Rule {
    var configuration = InvisibleCharacterConfiguration()

    // oida:disable invisible_character
    static let description = RuleDescription(
        identifier: "invisible_character",
        name: "Invisible Character",
        description: """
            Disallows invisible characters like zero-width space (U+200B), \
            zero-width non-joiner (U+200C), and FEFF formatting character (U+FEFF) \
            in string literals as they can cause hard-to-debug issues.
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            #"let s = "HelloWorld""#,
            #"let s = "Hello World""#,
            #"let url = "https://example.com/api""#,
            ##"let s = #"Hello World"#"##,
            """
            let multiline = \"\"\"
            Hello
            World
            \"\"\"
            """,
            #"let empty = """#,
            #"let tab = "Hello\tWorld""#,
            #"let newline = "Hello\nWorld""#,
            #"let unicode = "Hello 👋 World""#,
        ]),
        triggeringExamples: #examples([
            #"let s = "Hello↓​World" // U+200B zero-width space"#,
            #"let s = "Hello↓‌World" // U+200C zero-width non-joiner"#,
            #"let s = "Hello↓﻿World" // U+FEFF formatting character"#,
            #"let url = "https://example↓​.com" // U+200B in URL"#,
            """
            // U+200B in multiline string
            let multiline = \"\"\"
            Hello↓​World
            \"\"\"
            """,
            #"let s = "Test↓​String↓﻿Here" // Multiple invisible characters"#,
            #"let s = "Hel↓‌lo" + "World" // string concatenation with U+200C"#,
            #"let s = "Hel↓‌lo \(name)" // U+200C in interpolated string"#,
            """
            let s = "Hello↓­World"
            """.asExample(configuration: [
                "additional_code_points": ["00AD"],
            ]),
            """
            let s = "Hello↓‍World"
            """.asExample(configuration: [
                "additional_code_points": ["200D"],
            ]),
        ]),
        corrections: #corrections([
            #"let s = "Hello​World""#: #"let s = "HelloWorld""#,
            #"let s = "Hello‌World""#: #"let s = "HelloWorld""#,
            #"let s = "Hello﻿World""#: #"let s = "HelloWorld""#,
            #"let url = "https://example​.com""#: #"let url = "https://example.com""#,
            """
            let multiline = \"\"\"
            Hello​World
            \"\"\"
            """: """
            let multiline = \"\"\"
            HelloWorld
            \"\"\"
            """,
            #"let s = "Test​String﻿Here""#: #"let s = "TestStringHere""#,
            #"let s = "Hel‌lo" + "World""#: #"let s = "Hello" + "World""#,
            #"let s = "Hel‌lo \(name)""#: #"let s = "Hello \(name)""#,
            #"let s = "Hello­World""#.asExample(configuration: [
                    "additional_code_points": ["00AD"],
            ]): #"let s = "HelloWorld""#.asExample(configuration: [
                    "additional_code_points": ["00AD"],
            ]),
            #"let s = "Hello‍World""#.asExample(configuration: [
                    "additional_code_points": ["200D"],
            ]): #"let s = "HelloWorld""#.asExample(configuration: [
                    "additional_code_points": ["200D"],
            ]),
        ])
    )
    // oida:enable invisible_character
}

private extension InvisibleCharacterRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: StringLiteralExprSyntax) {
            let violatingCharacters = configuration.violatingCharacters
            for segment in node.segments {
                guard let stringSegment = segment.as(StringSegmentSyntax.self) else {
                    continue
                }
                let text = stringSegment.content.text
                let scalars = text.unicodeScalars
                guard scalars.contains(where: { violatingCharacters.contains($0) }) else {
                    continue
                }
                var utf8Offset = 0

                for scalar in scalars {
                    defer {
                        utf8Offset += scalar.utf8.count
                    }
                    guard violatingCharacters.contains(scalar) else {
                        continue
                    }

                    let characterName = InvisibleCharacterConfiguration.defaultCharacterDescriptions[scalar]
                        ?? scalar.escaped(asASCII: true)

                    let position = stringSegment.content.positionAfterSkippingLeadingTrivia.advanced(by: utf8Offset)
                    violations.append(
                        ReasonedRuleViolation(
                            position: position,
                            reason: "String literal should not contain invisible character \(characterName)",
                            correction: .init(
                                start: position,
                                end: position.advanced(by: scalar.utf8.count),
                                replacement: ""
                            )
                        )
                    )
                }
            }
        }
    }
}
