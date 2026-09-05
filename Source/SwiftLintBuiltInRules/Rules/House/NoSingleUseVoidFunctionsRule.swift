import SwiftLintCore
import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct NoSingleUseVoidFunctionsRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "no_single_use_void_functions",
        name: "No Single Use Void Functions",
        description: """
            A function that returns nothing states nothing in its signature about what it touches, so the \
            reader learns what it did by reading it. Called from one place, and reachable from nowhere but \
            this file, it is a jump that buys the reader nothing — put the statements where they run. A \
            function that returns a value is left alone: its name stands for the value, and that survives \
            only as long as the function does
            """,
        kind: .lint,
        nonTriggeringExamples: #examples([
            """
            struct Cart {
                func empty() { remove(.apple); remove(.pear) }
                private func remove(_ item: Item) { items.remove(item) }
            }
            """,
            """
            struct Generator {
                func run() { emit(looksMonetary(field)) }
                private func looksMonetary(_ name: String) -> Bool { name.hasSuffix("price") }
            }
            """,
            """
            struct Screen: View {
                var body: some View { header() }
                private func header() -> some View { Text("Basket") }
            }
            """,
            """
            final class Screen {
                func attach() { button.addTarget(self, action: #selector(tapped), for: .touchUpInside) }
                @objc private func tapped() { dismiss() }
            }
            """,
            """
            struct Cart {
                private func neverCalled() {}
            }
            """,
            """
            struct Cart {
                func show() { format(1); format("one") }
                private func format(_ value: Int) {}
                private func format(_ value: String) {}
            }
            """,
            """
            private struct Ledger: Recording {
                func post() { record() }
                func record() {}
            }
            """,
        ]),
        triggeringExamples: #examples([
            """
            struct Cart {
                func empty() { removeEverything() }
                private func ↓removeEverything() { items = [] }
            }
            """,
            """
            final class Loader {
                func load(_ data: Data) { decode(data) }
                fileprivate func ↓decode(_ data: Data) { store.write(data) }
            }
            """,
            """
            struct Screen {
                func appear() { reload() }
            }
            private extension Screen {
                func ↓reload() async { await store.load() }
            }
            """,
            """
            struct Screen {
                func appear() {
                    func ↓resetToggles() { isOn = false }
                    resetToggles()
                }
            }
            """,
        ])
    )
}

private extension NoSingleUseVoidFunctionsRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        private var declaredNames: [String] = []
        private var candidates: [(name: String, position: AbsolutePosition, body: Range<AbsolutePosition>)] = []
        private var references: [(name: String, position: AbsolutePosition)] = []

        override func visitPost(_ node: FunctionDeclSyntax) {
            declaredNames.append(node.name.text)
            guard node.isSingleUseCandidate else {
                return
            }
            candidates.append(
                (
                    node.name.text,
                    node.name.positionAfterSkippingLeadingTrivia,
                    node.positionAfterSkippingLeadingTrivia..<node.endPosition
                )
            )
        }

        override func visitPost(_ node: DeclReferenceExprSyntax) {
            references.append((node.baseName.text, node.positionAfterSkippingLeadingTrivia))
        }

        override func visitPost(_: SourceFileSyntax) {
            for candidate in candidates
            where declaredNames.filter({ $0 == candidate.name }).count == 1 {
                let callers = references.filter {
                    $0.name == candidate.name && !candidate.body.contains($0.position)
                }
                if callers.count == 1 {
                    violations.append(candidate.position)
                }
            }
        }
    }
}

private extension FunctionDeclSyntax {
    var isSingleUseCandidate: Bool {
        returnsNothing
            && isFileLocal
            && !modifiers.contains(where: \.isOverride)
            && !attributes.contains(where: \.hidesCallers)
    }

    var returnsNothing: Bool {
        guard let returnType = signature.returnClause?.type else {
            return true
        }
        let spelling = returnType.trimmedDescription
        return spelling == "Void" || spelling == "()"
    }

    var isFileLocal: Bool {
        if modifiers.contains(where: \.isPrivate) {
            return true
        }
        var ancestor = parent
        while let current = ancestor {
            if current.is(FunctionDeclSyntax.self) || current.is(ClosureExprSyntax.self) {
                return true
            }
            if let group = current.asProtocol(DeclGroupSyntax.self) {
                guard group.modifiers.contains(where: \.isPrivate) else {
                    return false
                }
                return current.is(ExtensionDeclSyntax.self) || group.inheritanceClause == nil
            }
            ancestor = current.parent
        }
        return false
    }
}

private extension DeclModifierSyntax {
    var isPrivate: Bool { name.tokenKind == .keyword(.private) || name.tokenKind == .keyword(.fileprivate) }
    var isOverride: Bool { name.tokenKind == .keyword(.override) }
}

private extension AttributeListSyntax.Element {
    var name: String? {
        guard case let .attribute(attribute) = self else {
            return nil
        }
        return attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text
    }

    var hidesCallers: Bool {
        name == "objc" || name == "IBAction" || name == "IBSegueAction"
    }
}
