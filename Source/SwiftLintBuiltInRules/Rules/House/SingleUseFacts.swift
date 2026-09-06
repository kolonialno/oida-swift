import Foundation
import SwiftSyntax

// What one file contributes to the call graph, and the resolver that reads all of them together. A call
// site is kept as the chain of names it was written with — `navigator.navigator(for: screen).resolve(…)` —
// and only resolved once every file's declared signatures are known, since the property and return types
// it walks through live in other files.

struct FileFacts: Hashable {
    var isTest: Bool
    var types: [TypeFacts]
    var candidates: [Candidate]
    var calls: [CallFacts]
}

struct TypeFacts: Hashable {
    let name: String
    let isProtocol: Bool
    /// False for an `extension`, which adds to a type declared elsewhere — possibly outside the run.
    let isDeclaration: Bool
    let supertypes: [String]
    let methods: [MethodFacts]
    let properties: [String: Binding]
}

struct MethodFacts: Hashable {
    let baseName: String
    let labels: [String]
    let returnType: String
    let isRequirement: Bool
    let isStatic: Bool

    var signature: String { "\(baseName)(\(labels.map { $0 + ":" }.joined()))" }
}

struct Candidate: Hashable {
    let owner: String
    let baseName: String
    let labels: [String]
    let position: AbsolutePosition

    var signature: String { "\(baseName)(\(labels.map { $0 + ":" }.joined()))" }
}

struct CallFacts: Hashable {
    let baseName: String
    /// `nil` when the function is passed as a value rather than called, so any labels could apply.
    let labels: [String]?
    let trailingClosures: Int
    let receiver: Receiver
    let enclosingType: String
    let enclosingSignature: String?
}

indirect enum Receiver: Hashable {
    case chain(root: Root, steps: [Step])
    /// `.foo(…)` with the type left to inference: only a static member can answer.
    case implicitMember
    case unresolvable(String)
}

enum Root: Hashable {
    case selfInstance
    case superInstance
    case type(String)
    /// A name bound nowhere in scope: a property of the enclosing type, a global, or a type used statically.
    case member(String)
}

enum Step: Hashable {
    case property(String)
    case call(baseName: String, labels: [String])
}

enum Binding: Hashable {
    case type(String)
    case chain(Root, [Step])
    case unknown
}

let globalScope = "<global>"
let externalType = "<external>"
