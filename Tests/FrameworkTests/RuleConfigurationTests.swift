import SourceKittenFramework
import TestHelpers
import Testing

@testable import SwiftLintBuiltInRules
@testable import SwiftLintCore

@Suite
struct RuleConfigurationTests {
    @Test
    func severityWorksAsOnlyParameter() throws {
        var config = AttributesConfiguration()
        #expect(config.severity == .warning)
        try config.apply(configuration: "error")
        #expect(config.severity == .error)
    }

    @Test
    func severityConfigurationFromString() {
        let config = "Warning"
        let comp = SeverityConfiguration<MockRule>(.warning)
        var severityConfig = SeverityConfiguration<MockRule>(.error)
        #expect(throws: Never.self) {
            try severityConfig.apply(configuration: config)
        }
        #expect(severityConfig == comp)
    }

    @Test
    func severityConfigurationFromDictionary() {
        let config = ["severity": "warning"]
        let comp = SeverityConfiguration<MockRule>(.warning)
        var severityConfig = SeverityConfiguration<MockRule>(.error)
        do {
            try severityConfig.apply(configuration: config)
            #expect(severityConfig == comp)
        } catch {
            Issue.record("Failed to configure severity from dictionary")
        }
    }

    @Test
    func severityConfigurationThrowsNothingApplied() {
        let config = 17
        var severityConfig = SeverityConfiguration<MockRule>(.error)
        #expect(throws: Issue.nothingApplied(ruleID: MockRule.identifier)) {
            try severityConfig.apply(configuration: config)
        }
    }

    @Test
    func severityConfigurationThrowsInvalidConfiguration() {
        let config = "foo"
        var severityConfig = SeverityConfiguration<MockRule>(.warning)
        #expect(throws: Issue.invalidConfiguration(ruleID: MockRule.identifier)) {
            try severityConfig.apply(configuration: config)
        }
    }

    @Test
    func severityLevelConfigParams() {
        let severityConfig = SeverityLevelsConfiguration<MockRule>(warning: 17, error: 7)
        #expect(
            severityConfig.params == [
                RuleParameter(severity: .error, value: 7),
                RuleParameter(severity: .warning, value: 17),
            ]
        )
    }

    @Test
    func severityLevelConfigPartialParams() {
        let severityConfig = SeverityLevelsConfiguration<MockRule>(warning: 17, error: nil)
        #expect(severityConfig.params == [RuleParameter(severity: .warning, value: 17)])
    }

    @Test
    func severityLevelConfigApplyNilErrorValue() throws {
        var severityConfig = SeverityLevelsConfiguration<MockRule>(warning: 17, error: 20)
        try severityConfig.apply(configuration: ["error": nil, "warning": 18])
        #expect(severityConfig.params == [RuleParameter(severity: .warning, value: 18)])
    }

    @Test
    func severityLevelConfigApplyMissingErrorValue() throws {
        var severityConfig = SeverityLevelsConfiguration<MockRule>(warning: 17, error: 20)
        try severityConfig.apply(configuration: ["warning": 18])
        #expect(severityConfig.params == [RuleParameter(severity: .warning, value: 18)])
    }

    @Test
    func regexConfigurationThrows() {
        let config = 17
        var regexConfig = RegexConfiguration<MockRule>(identifier: "")
        #expect(throws: Issue.invalidConfiguration(ruleID: MockRule.identifier)) {
            try regexConfig.apply(configuration: config)
        }
    }

    @Test
    func regexRuleDescription() {
        var regexConfig = RegexConfiguration<MockRule>(identifier: "regex")
        #expect(
            regexConfig.description
                == RuleDescription(
                    identifier: "regex",
                    name: "regex",
                    description: "", kind: .style))
        regexConfig.name = "name"
        #expect(
            regexConfig.description
                == RuleDescription(
                    identifier: "regex",
                    name: "name",
                    description: "", kind: .style))
    }

    @Test
    func overriddenSuperCallConfigurationFromDictionary() {
        var configuration = OverriddenSuperCallConfiguration()
        #expect(configuration.resolvedMethodNames.contains("viewWillAppear(_:)"))

        let conf1 = ["severity": "error", "excluded": "viewWillAppear(_:)"]
        #expect(throws: Never.self) {
            try configuration.apply(configuration: conf1)
        }
        #expect(configuration.severityConfiguration.severity == .error)
        #expect(!configuration.resolvedMethodNames.contains("*"))
        #expect(!configuration.resolvedMethodNames.contains("viewWillAppear(_:)"))
        #expect(configuration.resolvedMethodNames.contains("viewWillDisappear(_:)"))

        let conf2 = [
            "severity": "error",
            "excluded": "viewWillAppear(_:)",
            "included": ["*", "testMethod1()", "testMethod2(_:)"],
        ] as [String: any Sendable]
        #expect(throws: Never.self) {
            try configuration.apply(configuration: conf2)
        }
        #expect(configuration.severityConfiguration.severity == .error)
        #expect(!configuration.resolvedMethodNames.contains("*"))
        #expect(!configuration.resolvedMethodNames.contains("viewWillAppear(_:)"))
        #expect(configuration.resolvedMethodNames.contains("viewWillDisappear(_:)"))
        #expect(configuration.resolvedMethodNames.contains("testMethod1()"))
        #expect(configuration.resolvedMethodNames.contains("testMethod2(_:)"))

        let conf3 = [
            "severity": "warning",
            "excluded": "*",
            "included": ["testMethod1()", "testMethod2(_:)"],
        ] as [String: any Sendable]
        #expect(throws: Never.self) {
            try configuration.apply(configuration: conf3)
        }
        #expect(configuration.severityConfiguration.severity == .warning)
        #expect(configuration.resolvedMethodNames.count == 2)
        #expect(!configuration.resolvedMethodNames.contains("*"))
        #expect(configuration.resolvedMethodNames.contains("testMethod1()"))
        #expect(configuration.resolvedMethodNames.contains("testMethod2(_:)"))
    }

    @Test
    func modifierOrderConfigurationFromDictionary() throws {
        var configuration = ModifierOrderConfiguration()
        let config: [String: Any] = [
            "severity": "warning",
            "preferred_modifier_order": [
                "override",
                "acl",
                "setterACL",
                "owned",
                "mutators",
                "final",
                "typeMethods",
                "required",
                "convenience",
                "lazy",
                "dynamic",
            ],
        ]

        try configuration.apply(configuration: config)
        let expected: [SwiftDeclarationAttributeKind.ModifierGroup] = [
            .override,
            .acl,
            .setterACL,
            .owned,
            .mutators,
            .final,
            .typeMethods,
            .required,
            .convenience,
            .lazy,
            .dynamic,
        ]
        #expect(configuration.severityConfiguration.severity == .warning)
        #expect(configuration.preferredModifierOrder == expected)
    }

    @Test
    func modifierOrderConfigurationThrowsOnUnrecognizedModifierGroup() {
        var configuration = ModifierOrderConfiguration()
        let config =
            ["severity": "warning", "preferred_modifier_order": ["specialize"]]
            as [String: any Sendable]

        #expect(throws: Issue.invalidConfiguration(ruleID: ModifierOrderRule.identifier)) {
            try configuration.apply(configuration: config)
        }
    }

    @Test
    func modifierOrderConfigurationThrowsOnNonModifiableGroup() {
        var configuration = ModifierOrderConfiguration()
        let config = ["severity": "warning", "preferred_modifier_order": ["atPrefixed"]] as [String: any Sendable]
        #expect(throws: Issue.invalidConfiguration(ruleID: ModifierOrderRule.identifier)) {
            try configuration.apply(configuration: config)
        }
    }

    @Test
    func unusedParameterConfigurationFromDictionary() throws {
        var configuration = UnusedParameterConfiguration()
        try configuration.apply(configuration: ["severity": "error", "allow_underscore_prefixed_names": true])
        #expect(configuration.severity == .error)
        #expect(configuration.allowUnderscorePrefixedNames)
    }

    @Test
    func computedAccessorsOrderRuleConfiguration() throws {
        var configuration = ComputedAccessorsOrderConfiguration()
        let config = ["severity": "error", "order": "set_get"]
        try configuration.apply(configuration: config)
        #expect(configuration.severityConfiguration.severity == .error)
        #expect(configuration.order == .setGet)
        #expect(
            RuleConfigurationDescription.from(configuration: configuration).oneLiner()
                == "severity: error; order: set_get")
    }
}
