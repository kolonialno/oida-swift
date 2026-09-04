import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoUIApplicationSharedRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "no_uiapplication_shared",
        name: "No UIApplication Shared",
        description: """
            Reaching for the shared application instance is reaching around whatever injected seam this \
            code was handed instead — the navigator for a window, a link-opener for a URL, the composition \
            root for anything else. That seam is what a preview, a test or a second window can replace; \
            the singleton cannot be
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "NotificationCenter.default.post(name: .cartChanged, object: nil)",
            "URLSession.shared.dataTask(with: url)",
            "navigator.open(url)",
        ]),
        triggeringExamples: #examples([
            "↓UIApplication.shared.open(url)",
            "let keyWindow = ↓UIApplication.shared.connectedScenes.first",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension NoUIApplicationSharedRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: MemberAccessExprSyntax) {
            guard node.declName.baseName.text == "shared",
                node.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "UIApplication"
            else {
                return
            }
            violations.append(node.base?.positionAfterSkippingLeadingTrivia ?? node.positionAfterSkippingLeadingTrivia)
        }
    }
}
