import SwiftLintCore

@AutoConfigParser
struct BlanketDisableCommandConfiguration: SeverityBasedRuleConfiguration {
    @ConfigurationElement(key: "severity")
    private(set) var severityConfiguration = SeverityConfiguration<Parent>(.warning)
    @ConfigurationElement(key: "allowed_rules")
    /// Empty: a blanket disable suits a rule that judges the whole file, and oida no longer has one.
    private(set) var allowedRuleIdentifiers: Set<String> = []
    @ConfigurationElement(key: "always_blanket_disable")
    private(set) var alwaysBlanketDisableRuleIdentifiers: Set<String> = []
}
