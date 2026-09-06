import SwiftLintCore
import SwiftSyntax

struct NoSingleUseVoidFunctionsRule: CollectingRule, OptInRule, SourceKitFreeRule {
    struct FileNames: Hashable {
        /// Functions declared here that return nothing, by name, with where to report and what to skip.
        var candidates: [Candidate]
        /// How many times each name is declared as a function here, so an overloaded name is left alone.
        var declarations: [String: Int]
        /// How often each identifier is written here, the declaration's own name included.
        var mentions: [String: Int]
        var isTest: Bool
    }

    struct Candidate: Hashable {
        let name: String
        let position: AbsolutePosition
        let mentionsInOwnBody: Int
    }

    typealias FileInfo = FileNames

    var configuration = NoSingleUseVoidFunctionsConfiguration()

    static let description = RuleDescription(
        identifier: "no_single_use_void_functions",
        name: "No Single Use Void Functions",
        description: """
            A function that returns nothing states nothing in its signature about what it touches, so the \
            reader learns what it did by reading it. Called once from the file that declares it, it is a \
            jump that buys the reader nothing — put the statements where they run. A call from another \
            file is an interface across a layer rather than a jump, and a call from a test neither saves \
            a function nor condemns it, so neither counts
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
            final class SupportChatViewModel {
                func sendImage(_ data: Data) { transport.send(data) }
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
            struct ProductListsView: View {
                var body: some View { Button("New") { navigateToCreateList() } }
                func ↓navigateToCreateList() { navigator.navigate(to: .createList) }
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

    func collectInfo(for file: SwiftLintFile) -> FileNames {
        let visitor = Collector(viewMode: .sourceAccurate)
        visitor.walk(file.syntaxTree)
        return FileNames(
            candidates: visitor.candidates,
            declarations: visitor.declarations,
            mentions: visitor.mentions,
            isTest: file.isTest(matching: configuration.testPathFragments)
        )
    }

    func validate(file: SwiftLintFile, collectedInfo: [SwiftLintFile: FileNames]) -> [StyleViolation] {
        guard let own = collectedInfo[file], !own.isTest else {
            return []
        }
        let production = collectedInfo.filter { !$0.value.isTest }
        return own.candidates.compactMap { candidate in
            let declaredEverywhere = production.values.reduce(0) { $0 + ($1.declarations[candidate.name] ?? 0) }
            guard declaredEverywhere == 1 else {
                return nil
            }
            let elsewhere = production
                .filter { $0.key != file }
                .contains { ($0.value.mentions[candidate.name] ?? 0) > 0 }
            guard !elsewhere else {
                return nil
            }
            // A recursive call is not a caller, and the declaration's own name is a token rather than a
            // reference, so it was never counted.
            let callers = (own.mentions[candidate.name] ?? 0) - candidate.mentionsInOwnBody
            guard callers == 1 else {
                return nil
            }
            return StyleViolation(
                ruleDescription: Self.description,
                severity: configuration.severity,
                location: Location(file: file, position: candidate.position)
            )
        }
    }
}

private final class Collector: SyntaxVisitor {
    var candidates: [NoSingleUseVoidFunctionsRule.Candidate] = []
    var declarations: [String: Int] = [:]
    var mentions: [String: Int] = [:]

    override func visitPost(_ node: DeclReferenceExprSyntax) {
        mentions[node.baseName.text, default: 0] += 1
    }

    override func visitPost(_ node: FunctionDeclSyntax) {
        let name = node.name.text
        declarations[name, default: 0] += 1
        guard node.returnsNothing, !node.modifiers.contains(where: \.isOverride),
            !node.attributes.contains(where: \.hidesCallers)
        else {
            return
        }
        let inOwnBody = node.body.map { body in
            SelfMentions(name: name, viewMode: .sourceAccurate).count(in: body)
        } ?? 0
        candidates.append(
            .init(
                name: name,
                position: node.name.positionAfterSkippingLeadingTrivia,
                mentionsInOwnBody: inOwnBody
            )
        )
    }
}

private final class SelfMentions: SyntaxVisitor {
    private let name: String
    private var found = 0

    init(name: String, viewMode: SyntaxTreeViewMode) {
        self.name = name
        super.init(viewMode: viewMode)
    }

    func count(in body: CodeBlockSyntax) -> Int {
        found = 0
        walk(body)
        return found
    }

    override func visitPost(_ node: DeclReferenceExprSyntax) {
        if node.baseName.text == name {
            found += 1
        }
    }
}

private extension SwiftLintFile {
    func isTest(matching fragments: [String]) -> Bool {
        guard let path = path?.filepath else {
            return false
        }
        return fragments.contains { path.contains($0) }
    }
}

private extension FunctionDeclSyntax {
    var returnsNothing: Bool {
        guard let returnType = signature.returnClause?.type else {
            return true
        }
        let spelling = returnType.trimmedDescription
        return spelling == "Void" || spelling == "()"
    }
}

private extension DeclModifierSyntax {
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
