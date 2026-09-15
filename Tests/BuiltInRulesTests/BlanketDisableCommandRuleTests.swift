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
        let nonTriggeringExamples = #examples(["// oida:disable colon\n// oida:enable colon"])
        verifyRule(Self.emptyDescription.with(nonTriggeringExamples: nonTriggeringExamples))

        let triggeringExamples = #examples([
            "// oida:disable colon\n// oida:enable ↓colon",
            "// oida:disable:previous ↓colon",
            "// oida:disable:this ↓colon",
            "// oida:disable:next ↓colon",
        ])
        verifyRule(
            Self.emptyDescription.with(triggeringExamples: triggeringExamples),
            ruleConfiguration: ["always_blanket_disable": ["colon"]],
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
