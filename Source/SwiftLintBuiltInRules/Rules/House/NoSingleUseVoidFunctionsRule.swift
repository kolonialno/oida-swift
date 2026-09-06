import Foundation
import SwiftLintCore
import SwiftSyntax

struct NoSingleUseVoidFunctionsRule: CollectingRule, OptInRule, SourceKitFreeRule {
    typealias FileInfo = FileFacts

    var configuration = NoSingleUseVoidFunctionsConfiguration()

    static let description = RuleDescription(
        identifier: "no_single_use_void_functions",
        name: "No Single Use Void Functions",
        description: """
            A function that returns nothing states nothing in its signature about what it touches, so the \
            reader learns what it did by reading it. Called from exactly one place in the app, it is a jump \
            that buys the reader nothing — put the statements where they run. A call from a test neither \
            saves a function nor condemns it, so tests are not counted
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
            protocol Recording { func record() }
            struct Ledger: Recording {
                func post() { record() }
                func record() {}
            }
            """,
            """
            struct Screen {
                let store: Store
                func appear() { store.reload(); store.reload() }
            }
            struct Store {
                func reload() {}
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
            struct ProductListsView: View {
                var body: some View { Button("New") { navigateToCreateList() } }
                func ↓navigateToCreateList() { navigator.navigate(to: .createList) }
            }
            """,
            """
            struct Screen {
                let store: Store
                func appear() { store.reload() }
            }
            struct Store {
                func ↓reload() { cache.removeAll() }
            }
            """,
            """
            struct Chassis {
                let navigator: Navigator
                func fail(_ error: Error) {
                    let screen = navigator.navigator(for: current)
                    screen.resolve(into: error)
                }
            }
            struct Navigator {
                func navigator(for screen: Screen) -> ScreenNavigator { ScreenNavigator() }
            }
            struct ScreenNavigator {
                func ↓resolve(into failure: Error) { show(.error(failure)) }
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

    func collectInfo(for file: SwiftLintFile) -> FileFacts {
        let collector = CallGraphCollector(viewMode: .sourceAccurate)
        collector.walk(file.syntaxTree)
        let (types, candidates, calls) = collector.finish()
        return FileFacts(
            isTest: file.isTest(matching: configuration.testPathFragments),
            types: types,
            candidates: candidates,
            calls: calls
        )
    }

    func validate(file: SwiftLintFile, collectedInfo: [SwiftLintFile: FileFacts]) -> [StyleViolation] {
        guard let own = collectedInfo[file], !own.isTest else {
            return []
        }
        let graph = CallGraphCache.shared.graph(for: collectedInfo)
        if ProcessInfo.processInfo.environment["OIDA_SINGLE_USE_DEBUG"] != nil, let path = file.path?.filepath {
            for candidate in own.candidates {
                let line = file.locationConverter.location(for: candidate.position).line
                let verdict = graph.verdict(for: candidate)
                let record = "\(path):\(line)\t\(candidate.owner).\(candidate.signature)\t\(verdict)\n"
                FileHandle.standardError.write(Data(record.utf8))
            }
        }
        return own.candidates
            .filter(graph.isSingleUse)
            .map { candidate in
                StyleViolation(
                    ruleDescription: Self.description,
                    severity: configuration.severity,
                    location: Location(file: file, position: candidate.position)
                )
            }
    }
}

/// The run's files are collected once and then validated one at a time; the graph over all of them is
/// built on the first validation and reused for the rest of that run. Every access goes through the lock.
private final class CallGraphCache: @unchecked Sendable {
    static let shared = CallGraphCache()

    private let lock = NSLock()
    private var key: Int?
    private var graph: CallGraph?

    func graph(for collectedInfo: [SwiftLintFile: FileFacts]) -> CallGraph {
        let fingerprint = collectedInfo.keys.reduce(collectedInfo.count) { $0 ^ $1.hashValue }
        lock.lock()
        defer { lock.unlock() }
        if let graph, key == fingerprint {
            return graph
        }
        let built = CallGraph(files: Array(collectedInfo.values))
        key = fingerprint
        graph = built
        return built
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
