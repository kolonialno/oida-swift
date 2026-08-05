import SwiftLintCore
import TestHelpers
import Testing

@testable import SwiftLintBuiltInRules

@Suite(.rulesRegistered)
struct BlanketDisableCommandRuleTests {
    private static let emptyDescription = BlanketDisableCommandRule.description
        .with(triggeringExamples: [])
        .with(nonTriggeringExamples: [])

    @Test
    func alwaysBlanketDisable() {
        let nonTriggeringExamples = #examples(["// oida:disable file_length\n// oida:enable file_length"])
        verifyRule(Self.emptyDescription.with(nonTriggeringExamples: nonTriggeringExamples))

        let triggeringExamples = #examples([
            "// oida:disable file_length\n// oida:enable ↓file_length",
            "// oida:disable:previous ↓file_length",
            "// oida:disable:this ↓file_length",
            "// oida:disable:next ↓file_length",
        ])
        verifyRule(
            Self.emptyDescription.with(triggeringExamples: triggeringExamples),
            ruleConfiguration: ["always_blanket_disable": ["file_length"]],
            skipCommentTests: true, skipDisableCommandTests: true)
    }

    @Test
    func alwaysBlanketDisabledAreAllowed() {
        let nonTriggeringExamples = #examples(["// oida:disable identifier_name\n"])
        verifyRule(
            Self.emptyDescription.with(nonTriggeringExamples: nonTriggeringExamples),
            ruleConfiguration: ["always_blanket_disable": ["identifier_name"], "allowed_rules": []],
            skipDisableCommandTests: true)
    }

    @Test
    func allowedRules() {
        let nonTriggeringExamples = #examples([
            "// oida:disable file_length",
            "// oida:disable single_test_class",
        ])
        verifyRule(Self.emptyDescription.with(nonTriggeringExamples: nonTriggeringExamples))
    }
}
