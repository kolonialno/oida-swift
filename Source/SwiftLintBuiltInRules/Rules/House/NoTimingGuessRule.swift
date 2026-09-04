import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoTimingGuessRule: Rule {
    var configuration = PathScopedConfiguration<Self>()

    static let description = RuleDescription(
        identifier: "no_timing_guess",
        name: "No Timing Guess",
        description: """
            A fixed delay before mutating state or presenting, dismissing or navigating is a guess at how \
            long an animation or transition takes, not a signal that it finished, and the guess is what \
            breaks first on another device or a slower run. Wait on the real completion instead — an \
            animation's completion block, a transaction's completion, or a state change the transition itself \
            reports
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            "navigator.navigate(to: .detail(item))",
            """
            UIView.animate(withDuration: 0.3) {
                view.alpha = 0
            } completion: { _ in
                view.removeFromSuperview()
            }
            """,
        ]),
        triggeringExamples: #examples([
            """
            DispatchQueue.main↓.asyncAfter(deadline: .now() + 0.5) {
                self.viewModel.deleteLocally(item: collection)
            }
            """,
            "queue↓.asyncAfter(deadline: .now() + delay) { dismiss() }",
        ])
    )

    func preprocess(file: SwiftLintFile) -> SourceFileSyntax? {
        configuration.scope.contains(file) ? file.syntaxTree : nil
    }
}

private extension NoTimingGuessRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard node.calledMemberName == "asyncAfter",
                node.firstArgumentLabel == "deadline",
                let position = node.calledMemberPeriodPosition
            else {
                return
            }
            violations.append(position)
        }
    }
}
