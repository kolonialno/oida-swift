import Foundation
import SwiftSyntax

final class CallGraphCollector: SyntaxVisitor {
    private struct TypeBuilder {
        let name: String
        let isProtocol: Bool
        let isDeclaration: Bool
        let supertypes: [String]
        var methods: [MethodFacts] = []
        var properties: [String: Binding] = [:]

        var facts: TypeFacts {
            TypeFacts(name: name, isProtocol: isProtocol, isDeclaration: isDeclaration, supertypes: supertypes,
                      methods: methods, properties: properties)
        }
    }

    private(set) var types: [TypeFacts] = []
    private(set) var candidates: [Candidate] = []
    private(set) var calls: [CallFacts] = []

    private var typeStack: [TypeBuilder] = []
    private var globals = TypeBuilder(name: globalScope, isProtocol: false, isDeclaration: true, supertypes: [])
    private var functionStack: [String] = []
    private var scopes: [[String: Binding]] = []

    func finish() -> (types: [TypeFacts], candidates: [Candidate], calls: [CallFacts]) {
        types.append(globals.facts)
        return (types, candidates, calls)
    }

    // Types

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        pushType(node.name.text, isProtocol: false, isDeclaration: true, inheriting: node.inheritanceClause)
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        pushType(node.name.text, isProtocol: false, isDeclaration: true, inheriting: node.inheritanceClause)
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        pushType(node.name.text, isProtocol: false, isDeclaration: true, inheriting: node.inheritanceClause)
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        pushType(node.name.text, isProtocol: false, isDeclaration: true, inheriting: node.inheritanceClause)
    }
    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        pushType(node.name.text, isProtocol: true, isDeclaration: true, inheriting: node.inheritanceClause)
    }
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        pushType(node.extendedType.simpleName, isProtocol: false, isDeclaration: false,
                 inheriting: node.inheritanceClause)
    }
    override func visitPost(_: StructDeclSyntax) { popType() }
    override func visitPost(_: ClassDeclSyntax) { popType() }
    override func visitPost(_: EnumDeclSyntax) { popType() }
    override func visitPost(_: ActorDeclSyntax) { popType() }
    override func visitPost(_: ProtocolDeclSyntax) { popType() }
    override func visitPost(_: ExtensionDeclSyntax) { popType() }

    private func pushType(
        _ name: String,
        isProtocol: Bool,
        isDeclaration: Bool,
        inheriting clause: InheritanceClauseSyntax?
    )
        -> SyntaxVisitorContinueKind {
        let supertypes = clause?.inheritedTypes.map(\.type.simpleName) ?? []
        // A nested type is named through its parents, so two `ViewModel`s in two views stay two types.
        let qualified = name.contains(".") || typeStack.isEmpty ? name : "\(typeStack.last!.name).\(name)"
        typeStack.append(TypeBuilder(name: qualified, isProtocol: isProtocol, isDeclaration: isDeclaration,
                                     supertypes: supertypes))
        return .visitChildren
    }

    private func popType() {
        if let builder = typeStack.popLast() {
            types.append(builder.facts)
        }
    }

    private var currentTypeName: String { typeStack.last?.name ?? globalScope }

    private func addMethod(_ method: MethodFacts) {
        if typeStack.isEmpty {
            globals.methods.append(method)
        } else {
            typeStack[typeStack.count - 1].methods.append(method)
        }
    }

    private func addProperty(_ name: String, bound: Binding) {
        if typeStack.isEmpty {
            globals.properties[name] = bound
        } else {
            typeStack[typeStack.count - 1].properties[name] = bound
        }
    }

    // Functions

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let baseName = node.name.text
        let labels = node.signature.parameterClause.parameters.map(\.firstName.text)
        let returnType = node.signature.returnClause?.type.simpleName ?? ""
        let isRequirement = node.body == nil
        let isStatic = node.modifiers.contains { [.keyword(.static), .keyword(.class)].contains($0.name.tokenKind) }
        let method = MethodFacts(baseName: baseName, labels: labels, returnType: returnType,
                                 isRequirement: isRequirement, isStatic: isStatic)
        addMethod(method)

        let returnsNothing = node.signature.returnClause
            .map { ["Void", "()"].contains($0.type.trimmedDescription) } ?? true
        let hidden = node.attributes.contains { element in
            guard case let .attribute(attribute) = element,
                let name = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text else { return false }
            return ["objc", "IBAction", "IBSegueAction"].contains(name)
        }
        let overrides = node.modifiers.contains { $0.name.tokenKind == .keyword(.override) }
        if node.body != nil, returnsNothing, !hidden, !overrides, baseName.first?.isLetter == true {
            candidates.append(Candidate(owner: currentTypeName, baseName: baseName, labels: labels,
                                        position: node.name.positionAfterSkippingLeadingTrivia))
        }

        var scope: [String: Binding] = [:]
        for parameter in node.signature.parameterClause.parameters {
            let internalName = (parameter.secondName ?? parameter.firstName).text
            scope[internalName] = .type(parameter.type.simpleName)
        }
        scopes.append(scope)
        functionStack.append(method.signature)
        return .visitChildren
    }

    override func visitPost(_: FunctionDeclSyntax) {
        scopes.removeLast()
        functionStack.removeLast()
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        var scope: [String: Binding] = [:]
        for parameter in node.signature.parameterClause.parameters {
            scope[(parameter.secondName ?? parameter.firstName).text] = .type(parameter.type.simpleName)
        }
        scopes.append(scope)
        return .visitChildren
    }

    override func visitPost(_: InitializerDeclSyntax) {
        scopes.removeLast()
    }

    override func visit(_: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        scopes.append([:])
        return .visitChildren
    }

    override func visitPost(_: DeinitializerDeclSyntax) {
        scopes.removeLast()
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        var scope: [String: Binding] = [:]
        switch node.signature?.parameterClause {
        case let .simpleInput(names)?:
            for name in names { scope[name.name.text] = .unknown }
        case let .parameterClause(clause)?:
            for parameter in clause.parameters {
                let internalName = (parameter.secondName ?? parameter.firstName).text
                scope[internalName] = parameter.type.map { .type($0.simpleName) } ?? .unknown
            }
        case nil:
            break
        }
        scopes.append(scope)
        return .visitChildren
    }

    override func visitPost(_: ClosureExprSyntax) {
        scopes.removeLast()
    }

    override func visit(_: AccessorBlockSyntax) -> SyntaxVisitorContinueKind {
        scopes.append([:])
        return .visitChildren
    }

    override func visitPost(_: AccessorBlockSyntax) {
        scopes.removeLast()
    }

    // Bindings

    override func visitPost(_ node: VariableDeclSyntax) {
        for binding in node.bindings {
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { continue }
            let bound = self.binding(annotation: binding.typeAnnotation?.type, initializer: binding.initializer?.value)
            if scopes.isEmpty {
                addProperty(name, bound: bound)
            } else {
                scopes[scopes.count - 1][name] = bound
            }
        }
    }

    override func visitPost(_ node: OptionalBindingConditionSyntax) {
        guard let name = node.pattern.as(IdentifierPatternSyntax.self)?.identifier.text, !scopes.isEmpty else { return }
        let unwrapped = node.initializer?.value ?? ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(name)))
        scopes[scopes.count - 1][name] = binding(annotation: node.typeAnnotation?.type, initializer: unwrapped)
    }

    private func binding(annotation: TypeSyntax?, initializer: ExprSyntax?) -> Binding {
        if let annotation {
            let name = annotation.simpleName
            return name.isEmpty ? .unknown : .type(name)
        }
        guard let initializer, case let .chain(root, steps) = flatten(initializer) else { return .unknown }
        return .chain(root, steps)
    }

    // Calls

    override func visitPost(_ node: FunctionCallExprSyntax) {
        let labels = node.arguments.map { $0.label?.text ?? "_" }
        let trailing = (node.trailingClosure == nil ? 0 : 1) + node.additionalTrailingClosures.count
        let callee = node.calledExpression.unwrapped
        if let member = callee.as(MemberAccessExprSyntax.self) {
            let receiver = member.base.map(flatten) ?? .implicitMember
            record(baseName: member.declName.baseName.text, labels: labels, trailing: trailing, receiver: receiver)
        } else if let reference = callee.as(DeclReferenceExprSyntax.self) {
            let name = reference.baseName.text
            guard name.first?.isLowercase == true else { return }   // `Name(...)` builds a value
            guard lookup(name) == nil else { return }   // a local closure, not a method
            record(baseName: name, labels: labels, trailing: trailing, receiver: .chain(root: .selfInstance, steps: []))
        }
    }

    override func visitPost(_ node: DeclReferenceExprSyntax) {
        // A function handed on as a value. The callee of a call, and the name after a dot, are handled above.
        if let parent = node.parent {
            if let call = parent.as(FunctionCallExprSyntax.self), call.calledExpression.id == node.id { return }
            if let member = parent.as(MemberAccessExprSyntax.self) {
                if member.declName.id == node.id {
                    if let grand = member.parent?.as(FunctionCallExprSyntax.self),
                       grand.calledExpression.id == member.id {
                        return
                    }
                    let receiver = member.base.map(flatten) ?? .implicitMember
                    record(baseName: node.baseName.text, labels: nil, trailing: 0, receiver: receiver)
                }
                return
            }
        }
        let name = node.baseName.text
        guard name.first?.isLowercase == true, lookup(name) == nil else { return }
        record(baseName: name, labels: nil, trailing: 0, receiver: .chain(root: .selfInstance, steps: []))
    }

    private func record(baseName: String, labels: [String]?, trailing: Int, receiver: Receiver) {
        calls.append(CallFacts(baseName: baseName, labels: labels, trailingClosures: trailing, receiver: receiver,
                               enclosingType: currentTypeName, enclosingSignature: functionStack.last))
    }

    private func lookup(_ name: String) -> Binding? {
        for scope in scopes.reversed() {
            if let binding = scope[name] { return binding }
        }
        return nil
    }

    /// The chain of names an expression was written as, from its root identifier outwards.
    private func flatten(_ expression: ExprSyntax) -> Receiver {
        let expression = expression.unwrapped
        if let reference = expression.as(DeclReferenceExprSyntax.self) { return flatten(reference: reference) }
        if let member = expression.as(MemberAccessExprSyntax.self) {
            guard let base = member.base else { return .unresolvable("implicit member value") }
            guard case let .chain(root, steps) = flatten(base) else { return flatten(base) }
            return .chain(root: root, steps: steps + [.property(member.declName.baseName.text)])
        }
        if let literal = expression.literalTypeName { return .chain(root: .type(literal), steps: []) }
        if let call = expression.as(FunctionCallExprSyntax.self) { return flatten(call: call) }
        return .unresolvable("expression: \(expression.kind)")
    }

    private func flatten(reference: DeclReferenceExprSyntax) -> Receiver {
        let name = reference.baseName.text
        switch name {
        case "self": return .chain(root: .selfInstance, steps: [])
        case "super": return .chain(root: .superInstance, steps: [])
        case "Self": return .chain(root: .type(currentTypeName), steps: [])
        default: break
        }
        if name.hasPrefix("$") { return .unresolvable("closure shorthand") }
        switch lookup(name) {
        case .type(let type): return .chain(root: .type(type), steps: [])
        case let .chain(root, steps): return .chain(root: root, steps: steps)
        case .unknown: return .unresolvable("untyped binding")
        case nil: return .chain(root: .member(name), steps: [])
        }
    }

    private func flatten(call: FunctionCallExprSyntax) -> Receiver {
        let labels = call.arguments.map { $0.label?.text ?? "_" }
        var callee = call.calledExpression.unwrapped
        if let specialized = callee.as(GenericSpecializationExprSyntax.self) {
            callee = specialized.expression.unwrapped
        }
        if let literal = callee.literalTypeName { return .chain(root: .type(literal), steps: []) }
        if let reference = callee.as(DeclReferenceExprSyntax.self) {
            let name = reference.baseName.text
            if name.first?.isUppercase == true, lookup(name) == nil { return .chain(root: .type(name), steps: []) }
            return .chain(root: .selfInstance, steps: [.call(baseName: name, labels: labels)])
        }
        if let member = callee.as(MemberAccessExprSyntax.self) {
            guard let base = member.base else { return .unresolvable("implicit member call") }
            guard case let .chain(root, steps) = flatten(base) else { return flatten(base) }
            return .chain(root: root, steps: steps + [.call(baseName: member.declName.baseName.text, labels: labels)])
        }
        return .unresolvable("call: \(callee.kind)")
    }
}

private extension ExprSyntax {
    var literalTypeName: String? {
        switch kind {
        case .arrayExpr: "Array"
        case .dictionaryExpr: "Dictionary"
        case .booleanLiteralExpr: "Bool"
        case .stringLiteralExpr: "String"
        case .integerLiteralExpr: "Int"
        case .floatLiteralExpr: "Double"
        default: nil
        }
    }

    var unwrapped: ExprSyntax {
        var current = self
        while true {
            if let inner = current.as(TryExprSyntax.self) { current = inner.expression; continue }
            if let inner = current.as(AwaitExprSyntax.self) { current = inner.expression; continue }
            if let inner = current.as(ForceUnwrapExprSyntax.self) { current = inner.expression; continue }
            if let inner = current.as(OptionalChainingExprSyntax.self) { current = inner.expression; continue }
            if let tuple = current.as(TupleExprSyntax.self), tuple.elements.count == 1,
               let only = tuple.elements.first {
                current = only.expression; continue
            }
            return current
        }
    }
}

extension TypeSyntax {
    /// The name a value of this type resolves members against, or "" where members cannot be looked up by name.
    var simpleName: String {
        if let optional = `as`(OptionalTypeSyntax.self) { return optional.wrappedType.simpleName }
        if let optional = `as`(ImplicitlyUnwrappedOptionalTypeSyntax.self) { return optional.wrappedType.simpleName }
        if let opaque = `as`(SomeOrAnyTypeSyntax.self) { return opaque.constraint.simpleName }
        if let attributed = `as`(AttributedTypeSyntax.self) { return attributed.baseType.simpleName }
        if let tuple = `as`(TupleTypeSyntax.self), tuple.elements.count == 1, let only = tuple.elements.first {
            return only.type.simpleName
        }
        if let identifier = `as`(IdentifierTypeSyntax.self) { return identifier.name.text }
        if `is`(ArrayTypeSyntax.self) { return "Array" }
        if `is`(DictionaryTypeSyntax.self) { return "Dictionary" }
        if let member = `as`(MemberTypeSyntax.self) {
            let base = member.baseType.simpleName
            return base.isEmpty ? member.name.text : "\(base).\(member.name.text)"
        }
        return ""
    }
}
