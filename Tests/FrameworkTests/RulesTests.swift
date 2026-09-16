import TestHelpers
import Testing

@testable import SwiftLintBuiltInRules

@Suite(.rulesRegistered)
struct RulesTests {
    @Test
    func leadingWhitespace() {
        verifyRule(
            ForceCastRule.description, skipDisableCommandTests: true,
            testMultiByteOffsets: false, testShebang: false
        )
    }

    @Test
    func mark() {
        verifyRule(MarkRule.description, skipCommentTests: true)
    }

    @Test
    func trailingNewline() {
        verifyRule(
            TrailingNewlineRule.description, commentDoesntViolate: false,
            stringDoesntViolate: false
        )
    }

    @Test
    func orphanedDocComment() {
        verifyRule(OrphanedDocCommentRule.description, commentDoesntViolate: false, skipCommentTests: true)
    }
}
