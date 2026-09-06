import Foundation
import SwiftSyntax

/// Every production file's facts merged, with each call attributed once. Built once per run, read from
/// many threads afterwards, so everything it answers from is computed in `init`.
final class CallGraph {
    private struct MergedType {
        var isProtocol = false
        var isDeclared = false
        var supertypes: [String] = []
        var methods: [MethodFacts] = []
        var properties: [String: Binding] = [:]
    }

    private enum Attribution {
        case target(owner: String, signature: String)
        case ambiguous(String)
        case outside
    }

    enum Verdict: CustomStringConvertible {
        case witness, overloaded, poisoned(String), callers(Int)

        var description: String {
            switch self {
            case .witness: "witness"
            case .overloaded: "overloaded"
            case let .poisoned(reason): "poisoned(\(reason))"
            case let .callers(count): "callers=\(count)"
            }
        }
        var isSingleUse: Bool {
            if case .callers(1) = self { return true }
            return false
        }
    }

    private var types: [String: MergedType] = [:]
    private var lineages: [String: [String]] = [:]
    private var methodsByName: [String: [String: [MethodFacts]]] = [:]
    private var requirementsInLineage: [String: Set<String>] = [:]
    private var declaredTypes: Set<String> = []
    private var externalAncestry: Set<String> = []
    private var callers: [String: Int] = [:]
    private var poisonedByName: [String: [(labels: [String]?, trailing: Int, reason: String)]] = [:]
    private var staticsByName: [String: [(owner: String, method: MethodFacts)]] = [:]

    init(files: [FileFacts]) {
        let production = files.filter { !$0.isTest }
        merge(production)
        index()
        attribute(production)
    }

    private func merge(_ files: [FileFacts]) {
        for file in files {
            for type in file.types {
                var merged = types[type.name] ?? MergedType()
                merged.isProtocol = merged.isProtocol || type.isProtocol
                merged.isDeclared = merged.isDeclared || type.isDeclaration
                merged.supertypes += type.supertypes
                merged.methods += type.methods
                merged.properties.merge(type.properties) { current, new in current == .unknown ? new : current }
                types[type.name] = merged
            }
        }
        declaredTypes = Set(types.filter(\.value.isDeclared).keys)
    }

    private func index() {
        for (name, type) in types {
            let lineage = computeLineage(of: name)
            lineages[name] = lineage
            if lineage.contains(where: { ancestor in
                !declaredTypes.contains(ancestor)
                    || types[ancestor]!.supertypes.contains { qualify($0, from: ancestor) == nil }
            }) {
                externalAncestry.insert(name)
            }
            methodsByName[name] = Dictionary(grouping: type.methods, by: \.baseName)
            for method in type.methods where method.isStatic {
                staticsByName[method.baseName, default: []].append((name, method))
            }
        }
        for name in types.keys {
            var requirements: Set<String> = []
            for ancestor in lineages[name] ?? [] where ancestor != name || types[ancestor]?.isProtocol == true {
                for method in types[ancestor]?.methods ?? [] where method.isRequirement {
                    requirements.insert(method.signature)
                }
            }
            requirementsInLineage[name] = requirements
        }
    }

    private func attribute(_ files: [FileFacts]) {
        let traced = ProcessInfo.processInfo.environment["OIDA_SINGLE_USE_TRACE"]
        for file in files {
            for call in file.calls {
                let attribution = attribute(call)
                if let traced, call.baseName == traced {
                    let arguments = call.labels.map { $0.joined(separator: ":") } ?? "value"
                    let line = "trace \(call.enclosingType).\(call.enclosingSignature ?? "-"): \(call.receiver) "
                        + ".\(call.baseName)(\(arguments)) +\(call.trailingClosures) -> \(attribution)\n"
                    FileHandle.standardError.write(Data(line.utf8))
                }
                switch attribution {
                case let .target(owner, signature):
                    if call.enclosingType == owner, call.enclosingSignature == signature { continue }   // recursion
                    callers["\(owner).\(signature)", default: 0] += 1
                case let .ambiguous(reason):
                    poisonedByName[call.baseName, default: []].append((call.labels, call.trailingClosures, reason))
                case .outside:
                    break
                }
            }
        }
    }

    func verdict(for candidate: Candidate) -> Verdict {
        if requirementsInLineage[candidate.owner]?.contains(candidate.signature) == true { return .witness }
        let sameLabels = methodsByName[candidate.owner]?[candidate.baseName]?.filter { $0.labels == candidate.labels }
        if (sameLabels?.count ?? 0) > 1 {
            return .overloaded
        }
        if let poison = poisonedByName[candidate.baseName]?
            .first(where: { labelsCompatible(call: $0.labels, declared: candidate.labels) }) {
            return .poisoned(poison.reason)
        }
        return .callers(callers["\(candidate.owner).\(candidate.signature)"] ?? 0)
    }

    func isSingleUse(_ candidate: Candidate) -> Bool { verdict(for: candidate).isSingleUse }

    private func attribute(_ call: CallFacts) -> Attribution {
        switch call.receiver {
        case let .unresolvable(reason):
            return .ambiguous(reason)
        case .implicitMember:
            let matches = (staticsByName[call.baseName] ?? []).filter {
                labelsCompatible(call: call.labels, declared: $0.method.labels)
            }
            guard let only = matches.first else { return .outside }
            guard matches.count == 1 else { return .ambiguous("implicit member, several statics") }
            return .target(owner: only.owner, signature: only.method.signature)
        case let .chain(root, steps):
            guard var current = resolve(root: root, enclosing: call.enclosingType) else {
                return .ambiguous("root: \(root) in \(call.enclosingType)")
            }
            for step in steps {
                guard let next = resolve(step: step, on: current) else {
                    return .ambiguous("step: \(step) on \(current) in \(call.enclosingType)")
                }
                current = next
            }
            return locate(call, on: current)
        }
    }

    /// A type written as a simple name inside a nested type may mean a sibling nested type first.
    private func qualify(_ written: String, from context: String) -> String? {
        if types[written] != nil, written.contains(".") { return written }
        var scope = context
        while true {
            let candidate = scope.isEmpty || scope == globalScope ? written : "\(scope).\(written)"
            if types[candidate] != nil { return candidate }
            let parents = scope.split(separator: ".").dropLast()
            guard !parents.isEmpty else { break }
            scope = parents.joined(separator: ".")
        }
        return types[written] != nil ? written : nil
    }

    private func resolve(typeName: String, from context: String) -> String? {
        if typeName.isEmpty { return nil }
        return qualify(typeName, from: context) ?? (typeName.first?.isUppercase == true ? externalType : nil)
    }

    /// A property declared by its initializer alone (`let appState = TiendaAppState()`) is typed by resolving
    /// that expression where it was written; the depth cap ends two properties defined by each other.
    private func resolve(binding: Binding, from owner: String, depth: Int) -> String? {
        switch binding {
        case let .type(name): return resolve(typeName: name, from: owner)
        case let .chain(root, steps):
            guard depth < 4, var current = resolve(root: root, enclosing: owner, depth: depth + 1) else { return nil }
            for step in steps {
                guard let next = resolve(step: step, on: current, depth: depth + 1) else { return nil }
                current = next
            }
            return current
        case .unknown: return nil
        }
    }

    private func resolve(root: Root, enclosing: String, depth: Int = 0) -> String? {
        switch root {
        case .selfInstance: return enclosing
        case .superInstance:
            return types[enclosing]?.supertypes
                .compactMap { qualify($0, from: enclosing) }
                .first { !(types[$0]?.isProtocol ?? true) }
        case let .type(name): return resolve(typeName: name, from: enclosing)
        case let .member(name):
            if let (bound, owner) = property(name, on: enclosing) {
                return resolve(binding: bound, from: owner, depth: depth)
            }
            if let type = qualify(name, from: enclosing) { return type }
            if let bound = types[globalScope]?.properties[name] {
                return resolve(binding: bound, from: globalScope, depth: depth)
            }
            if name.first?.isUppercase == true { return externalType }
            return nil
        }
    }

    private func resolve(step: Step, on typeName: String, depth: Int = 0) -> String? {
        if typeName == externalType { return externalType }
        switch step {
        case let .property(name):
            if types["\(typeName).\(name)"] != nil { return "\(typeName).\(name)" }
            if let (bound, owner) = property(name, on: typeName) {
                return resolve(binding: bound, from: owner, depth: depth)
            }
            // Apple's singleton spellings hand back the type itself: `UIApplication.shared`, `RunLoop.main`.
            if ["shared", "default", "standard", "current", "main", "instance"].contains(name) { return typeName }
            // A type declared outside the run, or inheriting from one, has members we cannot see; a value read
            // off it stays outside.
            return externalAncestry.contains(typeName) ? externalType : nil
        case let .call(baseName, labels):
            let compatible = methods(named: baseName, on: typeName)
                .filter { labelsCompatible(call: labels, declared: $0.method.labels) }
            let matches = preferringExact(compatible, call: labels, trailing: 0)
            if matches.isEmpty { return externalAncestry.contains(typeName) ? externalType : nil }
            let returns = Set(matches.compactMap {
                $0.method.returnType.isEmpty ? nil : resolve(typeName: $0.method.returnType, from: $0.owner)
            })
            guard returns.count == 1, let type = returns.first else { return nil }
            return type
        }
    }

    private func computeLineage(of typeName: String) -> [String] {
        var seen: Set<String> = []
        var order: [String] = []
        var queue = [typeName]
        while !queue.isEmpty {
            let name = queue.removeFirst()
            guard seen.insert(name).inserted else { continue }
            order.append(name)
            queue += (types[name]?.supertypes ?? []).compactMap { qualify($0, from: name) }
        }
        return order
    }

    private func lineage(of typeName: String) -> [String] { lineages[typeName] ?? [typeName] }

    private func property(_ name: String, on typeName: String) -> (bound: Binding, owner: String)? {
        for ancestor in lineage(of: typeName) {
            if let bound = types[ancestor]?.properties[name] { return (bound, ancestor) }
        }
        return nil
    }

    private func methods(named baseName: String, on typeName: String) -> [(owner: String, method: MethodFacts)] {
        lineage(of: typeName).flatMap { owner in (methodsByName[owner]?[baseName] ?? []).map { (owner, $0) } }
    }

    private func locate(_ call: CallFacts, on typeName: String) -> Attribution {
        if typeName == externalType { return .outside }
        // A bare name that is a stored property is a value being read, not a function being passed on.
        if call.labels == nil, property(call.baseName, on: typeName) != nil { return .outside }
        var matches: [(owner: String, method: MethodFacts)] = []
        for ancestor in lineage(of: typeName) {
            for method in methodsByName[ancestor]?[call.baseName] ?? []
            where labelsCompatible(call: call.labels, declared: method.labels) {
                matches.append((ancestor, method))
            }
        }
        matches = preferringExact(matches, call: call.labels, trailing: call.trailingClosures)
        // A requirement and the witness answering it are one slot, not two candidates.
        let implementations = matches.filter { !$0.method.isRequirement }
        var effective = implementations.isEmpty ? matches : implementations
        if effective.isEmpty {   // a bare call inside a type may be to a free function
            effective = (methodsByName[globalScope]?[call.baseName] ?? [])
                .filter { labelsCompatible(call: call.labels, declared: $0.labels) }
                .map { (globalScope, $0) }
        }
        guard let only = effective.first else { return .outside }
        let distinct = Set(effective.map { "\($0.owner).\($0.method.signature)" })
        guard distinct.count == 1 else { return .ambiguous("\(distinct.count) methods match on \(typeName)") }
        return .target(owner: only.owner, signature: only.method.signature)
    }

    /// Swift ranks a declaration taking exactly the arguments written above one filling in defaults, so
    /// `report(error)` is `report(_:)` even where `report(_:from:)` could also take it.
    private func preferringExact(
        _ matches: [(owner: String, method: MethodFacts)], call: [String]?, trailing: Int
    ) -> [(owner: String, method: MethodFacts)] {
        guard let call else { return matches }
        let exact = matches.filter {
            $0.method.labels.count == call.count + trailing && Array($0.method.labels.prefix(call.count)) == call
        }
        return exact.isEmpty ? matches : exact
    }

    /// Arguments a call omitted are defaulted or trailing closures, so its labels must appear in the
    /// declaration's, in order.
    private func labelsCompatible(call: [String]?, declared: [String]) -> Bool {
        guard let call else { return true }
        var index = declared.startIndex
        for label in call {
            guard let found = declared[index...].firstIndex(of: label) else { return false }
            index = found + 1
        }
        return true
    }
}
