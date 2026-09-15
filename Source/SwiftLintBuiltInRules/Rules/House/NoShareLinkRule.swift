import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoShareLinkRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "no_share_link",
        name: "No ShareLink",
        description: """
            ShareLink presents its share sheet through Apple's remote-scene sharing bridge, and an \
            interactive (swipe-down) dismissal of that sheet leaves the window's touch delivery dead for the \
            rest of the session. Present through the navigator's share sheet destination instead
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "Button(\"Share\") { navigator.navigate(to: .shareSheet(items: [url])) }",
            "struct ShareSheetPresenter {}",
            "L10n.Referrals.ShareLink.text",
        ]),
        triggeringExamples: #examples([
            "↓ShareLink(item: url) { Label(\"Share\", systemImage: \"square.and.arrow.up\") }",
            "↓ShareLink(\"Share\", item: url)",
            "let link: ↓ShareLink<Label, Text>? = nil",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension NoShareLinkRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        /// A construction, `ShareLink(…)` — never `someBase.ShareLink(…)`, since it isn't a member.
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "ShareLink" else {
                return
            }
            violations.append(node.calledExpression.positionAfterSkippingLeadingTrivia)
        }

        /// A type reference, `ShareLink` or `ShareLink<Label, Item>` — never a member access, which is
        /// what a name like `L10n.Referrals.ShareLink.text` is.
        override func visitPost(_ node: IdentifierTypeSyntax) {
            guard node.name.text == "ShareLink" else {
                return
            }
            violations.append(node.positionAfterSkippingLeadingTrivia)
        }
    }
}
