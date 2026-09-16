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
        let nonTriggeringExamples = #examples(["// oida:disable force_cast\n// oida:enable force_cast"])
        verifyRule(Self.emptyDescription.with(nonTriggeringExamples: nonTriggeringExamples))

        let triggeringExamples = #examples([
            "// oida:disable force_cast\n// oida:enable ↓force_cast",
            "// oida:disable:previous ↓force_cast",
            "// oida:disable:this ↓force_cast",
            "// oida:disable:next ↓force_cast",
        ])
        verifyRule(
            Self.emptyDescription.with(triggeringExamples: triggeringExamples),
            ruleConfiguration: ["always_blanket_disable": ["force_cast"]],
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
            "// oida:disable file_name",
            "// oida:disable single_test_class",
        ])
        verifyRule(Self.emptyDescription.with(nonTriggeringExamples: nonTriggeringExamples))
    }
}
