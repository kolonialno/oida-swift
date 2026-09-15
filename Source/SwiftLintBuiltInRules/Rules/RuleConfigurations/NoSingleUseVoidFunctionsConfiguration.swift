import SwiftLintCore

@AutoConfigParser
struct NoSingleUseVoidFunctionsConfiguration: SeverityBasedRuleConfiguration {
    @ConfigurationElement(key: "severity")
    private(set) var severityConfiguration = SeverityConfiguration<Parent>(.warning)
    /// A call from a test neither saves a function nor condemns it, so tests are left out of the count.
    /// Path fragments rather than a target list, since the linter is given files and not a build.
    @ConfigurationElement(key: "test_path_fragments")
    private(set) var testPathFragments = ["Tests/", "UITests", "Tests.swift", "TestHelpers/", "Spec.swift"]
}
