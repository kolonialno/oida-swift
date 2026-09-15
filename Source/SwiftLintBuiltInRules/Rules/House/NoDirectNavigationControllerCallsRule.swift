import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoDirectNavigationControllerCallsRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "no_direct_navigation_controller_calls",
        name: "No Direct Navigation Controller Calls",
        description: """
            A raw NavigationLink or a direct push/present/pop/dismiss desyncs the navigator's tracked \
            stack the same way an untracked sheet does; navigate through the injected navigator instead
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "Button(item.name) { navigator.navigate(to: .productDetail(item.id)) }",
            "navigator.navigate(to: .cart)",
            "analyticsPresenter.present(event: .viewed)",
        ]),
        triggeringExamples: #examples([
            "↓NavigationLink(value: item) { Text(item.name) }",
            "↓NavigationLink(\"Detail\", destination: Detail())",
            "controller↓.pushViewController(detail, animated: true)",
            "controller↓.present(alert, animated: true)",
            "controller↓.popViewController(animated: true)",
            "controller↓.dismiss(animated: true)",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension NoDirectNavigationControllerCallsRule {
    /// Every one of these takes `animated:`, which is what tells a push/present/pop/dismiss call apart
    /// from an unrelated method that happens to share its name.
    static let calls: Set<String> = ["pushViewController", "present", "popViewController", "dismiss"]

    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: TokenSyntax) {
            guard case .identifier("NavigationLink") = node.tokenKind else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }

        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard let name = node.calledMemberName,
                NoDirectNavigationControllerCallsRule.calls.contains(name),
                node.arguments.contains(where: { $0.label?.text == "animated" }),
                let position = node.calledMemberPeriodPosition
            else {
                return
            }
            violations.append(position)
        }
    }
}
