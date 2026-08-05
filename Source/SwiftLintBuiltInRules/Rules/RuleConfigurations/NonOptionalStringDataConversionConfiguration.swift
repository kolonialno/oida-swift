import SwiftLintCore

@AutoConfigParser
struct NonOptionalStringDataConversionConfiguration: SeverityBasedRuleConfiguration {
    // oida:disable:previous type_name

    @ConfigurationElement(key: "severity")
    private(set) var severityConfiguration = SeverityConfiguration<Parent>(.warning)
    @ConfigurationElement(key: "include_variables")
    private(set) var includeVariables = false
}
