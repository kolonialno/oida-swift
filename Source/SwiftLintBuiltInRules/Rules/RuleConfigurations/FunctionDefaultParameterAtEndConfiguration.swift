import SwiftLintCore

@AutoConfigParser
struct FunctionDefaultParameterAtEndConfiguration: SeverityBasedRuleConfiguration {
    // oida:disable:previous type_name

    @ConfigurationElement(key: "severity")
    private(set) var severityConfiguration = SeverityConfiguration<Parent>(.warning)
    @ConfigurationElement(key: "ignore_first_isolation_inheritance_parameter")
    private(set) var ignoreFirstIsolationInheritanceParameter = true
}
