//
//  Extractor.swift
//  dagger-graph
//
//  Recorre el AST de SwiftSyntax y extrae los mismos hechos que usan las macros
//  (`DaggerSwiftMacrosPlugin`) para generar `register(in:)`, replicando sus reglas:
//  - `@Inject`: parámetros del primer `init` explícito; si no hay, stored properties
//    sin valor por defecto, sin `static`, sin `@Published/@State/@Binding`, sin accessors.
//  - `@Module`: funciones con @Singleton > @Scoped > @Provider > @BusinessRule > @Precondition.
//

import SwiftParser
import SwiftSyntax

final class FactExtractor: SyntaxVisitor {
    private let converter: SourceLocationConverter
    private var typeStack: [String] = []
    private(set) var facts = FileFacts()

    init(tree: SourceFileSyntax, fileName: String) {
        self.converter = SourceLocationConverter(fileName: fileName, tree: tree)
        super.init(viewMode: .sourceAccurate)
    }

    static func extract(from tree: SourceFileSyntax, fileName: String) -> FileFacts {
        let v = FactExtractor(tree: tree, fileName: fileName)
        v.walk(tree)
        return v.facts
    }

    private func loc(_ node: some SyntaxProtocol) -> Loc {
        let l = node.startLocation(converter: converter, afterLeadingTrivia: true)
        return Loc(line: l.line, col: l.column)
    }

    // MARK: - Tipos

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        handleType(name: node.name.text, attributes: node.attributes, members: node.memberBlock, node: node)
    }
    override func visitPost(_ node: StructDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        handleType(name: node.name.text, attributes: node.attributes, members: node.memberBlock, node: node)
    }
    override func visitPost(_ node: ClassDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        handleType(name: node.name.text, attributes: node.attributes, members: node.memberBlock, node: node)
    }
    override func visitPost(_ node: ActorDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        handleType(name: node.name.text, attributes: node.attributes, members: node.memberBlock, node: node)
    }
    override func visitPost(_ node: EnumDeclSyntax) { typeStack.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        typeStack.append(node.extendedType.trimmedDescription)
        return .visitChildren
    }
    override func visitPost(_ node: ExtensionDeclSyntax) { typeStack.removeLast() }

    private func handleType(
        name: String,
        attributes: AttributeListSyntax,
        members: MemberBlockSyntax,
        node: some SyntaxProtocol
    ) -> SyntaxVisitorContinueKind {
        typeStack.append(name)
        let qualified = typeStack.joined(separator: ".")

        if let inject = attribute(named: "Inject", in: attributes) {
            let scope = labeledArgument("scope", of: inject).map(TypeName.stripSelf)
            facts.bindings.append(
                Binding(
                    provides: qualified,
                    kind: .inject,
                    lifetime: scope.map { .scope($0) } ?? .transient,
                    origin: "@Inject \(qualified)",
                    loc: loc(node),
                    deps: injectDependencies(members),
                    spelledType: qualified,
                    isMainActor: attribute(named: "MainActor", in: attributes) != nil
                )
            )
        }

        if let module = attribute(named: "Module", in: attributes) {
            let moduleScope = labeledArgument("scope", of: module).map(TypeName.stripSelf)
            var includes: [String] = []
            if let arr = labeledArgumentExpr("includes", of: module)?.as(ArrayExprSyntax.self) {
                includes = arr.elements.map { TypeName.stripSelf($0.expression.trimmedDescription) }
            }
            facts.modules.append(ModuleFact(name: qualified, scope: moduleScope, includes: includes, loc: loc(node)))
            moduleBindings(members, module: qualified, moduleScope: moduleScope,
                           moduleIsMainActor: attribute(named: "MainActor", in: attributes) != nil)
        }
        return .visitChildren
    }

    // MARK: - @Inject

    private func injectDependencies(_ members: MemberBlockSyntax) -> [Dependency] {
        if let initDecl = members.members.lazy.compactMap({ $0.decl.as(InitializerDeclSyntax.self) }).first {
            // Igual que la macro: parámetros con valor por defecto no se resuelven del grafo.
            return initDecl.signature.parameterClause.parameters.filter { $0.defaultValue == nil }.map {
                Dependency(
                    type: TypeName.normalize($0.type.trimmedDescription),
                    loc: loc($0),
                    label: $0.firstName.text,
                    spelled: $0.type.trimmedDescription
                )
            }
        }
        var deps: [Dependency] = []
        for member in members.members {
            guard let v = member.decl.as(VariableDeclSyntax.self) else { continue }
            if v.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) { continue }
            let skipAttrs = ["Published", "State", "Binding"]
            if v.attributes.contains(where: { attrName($0).map(skipAttrs.contains) ?? false }) { continue }
            // `let a, b: Int`: `a` no tiene anotación; hereda el tipo de la siguiente que sí la tiene.
            var inherited: TypeSyntax?
            var typed: [(PatternBindingSyntax, TypeSyntax)] = []
            for b in v.bindings.reversed() {
                if let t = b.typeAnnotation?.type { inherited = t }
                if let t = b.typeAnnotation?.type ?? inherited { typed.append((b, t)) }
            }
            for (b, t) in typed.reversed() {
                guard b.initializer == nil, b.accessorBlock == nil else { continue }
                deps.append(Dependency(
                    type: TypeName.normalize(t.trimmedDescription),
                    loc: loc(b),
                    label: b.pattern.trimmedDescription,
                    spelled: t.trimmedDescription
                ))
            }
        }
        return deps
    }

    // MARK: - @Module

    private func moduleBindings(_ members: MemberBlockSyntax, module: String, moduleScope: String?, moduleIsMainActor: Bool = false) {
        for member in members.members {
            guard let fn = member.decl.as(FunctionDeclSyntax.self),
                  let ret = fn.signature.returnClause?.type else { continue }

            let attrs = fn.attributes
            let kind: BindingKind
            var lifetime: Lifetime = .transient
            if attribute(named: "Singleton", in: attrs) != nil {
                kind = .singleton
                lifetime = .root
            } else if let scoped = attribute(named: "Scoped", in: attrs) {
                kind = .scoped
                let custom = scoped.arguments?.as(LabeledExprListSyntax.self)?.first
                    .map { TypeName.stripSelf($0.expression.trimmedDescription) }
                lifetime = .scope(custom ?? moduleScope ?? module)
            } else if attribute(named: "Provider", in: attrs) != nil {
                kind = .provider
            } else if attribute(named: "BusinessRule", in: attrs) != nil {
                kind = .businessRule
            } else if attribute(named: "Precondition", in: attrs) != nil {
                kind = .precondition
            } else {
                continue
            }

            let reason = attribute(named: "Precondition", in: attrs)?.arguments?.as(LabeledExprListSyntax.self)?.first?
                .expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue
            var provides = TypeName.normalize(ret.trimmedDescription)
            if kind == .precondition, provides.hasSuffix("?") { provides.removeLast() }

            facts.bindings.append(
                Binding(
                    provides: provides,
                    kind: kind,
                    lifetime: lifetime,
                    origin: "\(module).\(fn.name.text)()",
                    loc: loc(fn.name),
                    deps: fn.signature.parameterClause.parameters.filter { $0.defaultValue == nil }.map {
                        Dependency(
                            type: TypeName.normalize($0.type.trimmedDescription),
                            loc: loc($0),
                            label: $0.firstName.text,
                            spelled: $0.type.trimmedDescription
                        )
                    },
                    module: module,
                    function: fn.name.text,
                    isThrowing: fn.signature.effectSpecifiers?.throwsClause != nil,
                    spelledType: ret.trimmedDescription,
                    // Igual que la macro: @MainActor en la función, o en el módulo salvo `nonisolated`.
                    isMainActor: attribute(named: "MainActor", in: attrs) != nil
                        || (moduleIsMainActor && !fn.modifiers.contains { $0.name.text == "nonisolated" }),
                    reason: reason
                )
            )
        }
    }

    // MARK: - Registros dinámicos (runtime)

    private static let dynamicCalls: Set<String> = [
        "bindInstance", "provideSingleton", "provideScoped", "provide", "provideBusinessRule", "providePrecondition",
    ]

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
              Self.dynamicCalls.contains(member.declName.baseName.text) else { return .visitChildren }
        let call = member.declName.baseName.text
        var type: String?
        if call == "bindInstance" {
            type = node.arguments.first(where: { $0.label?.text == "as" }).map { TypeName.stripSelf($0.expression.trimmedDescription) }
        } else {
            type = node.arguments.first(where: { $0.label == nil && $0.expression.trimmedDescription.hasSuffix(".self") })
                .map { TypeName.stripSelf($0.expression.trimmedDescription) }
        }
        facts.dynamic.append(DynamicRegistration(call: call, type: type, loc: loc(node)))
        return .visitChildren
    }

    // MARK: - Raíces de composición

    /// Variables locales que apuntan a una raíz (`let root = ScopeContainer.root(modules: ...)`).
    private var rootVariables: [String: Int] = [:]
    private var rootIndexByCall: [SyntaxIdentifier: Int] = [:]

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        rootVariables.removeAll()
        return .visitChildren
    }

    override func visitPost(_ node: VariableDeclSyntax) {
        for binding in node.bindings {
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  let value = binding.initializer?.value,
                  let call = Self.unwrapCall(value),
                  let index = rootIndexByCall[call.id] else { continue }
            rootVariables[name] = index
        }
    }

    /// Post-orden: la llamada interna (`ScopeContainer.root(...)`) se registra antes que la externa
    /// (`.makeChildScope(...)`), así el hijo encuentra a su padre.
    override func visitPost(_ node: FunctionCallExprSyntax) {
        if let root = rootFact(for: node) {
            facts.roots.append(root)
            rootIndexByCall[node.id] = facts.roots.count - 1
            return
        }
        // `x.resolve(T.self)` sobre una raíz conocida (variable local o llamada encadenada).
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
              member.declName.baseName.text == "resolve",
              let base = member.base,
              let first = node.arguments.first, first.label == nil,
              first.expression.trimmedDescription.hasSuffix(".self") else { return }
        var index: Int?
        if let ref = base.as(DeclReferenceExprSyntax.self) {
            index = rootVariables[ref.baseName.text]
        } else if let call = Self.unwrapCall(base) {
            index = rootIndexByCall[call.id]
        }
        guard let index else { return }
        facts.roots[index].requested.append(RootFact.Requested(
            type: TypeName.stripSelf(first.expression.trimmedDescription),
            loc: loc(node),
            expectsFailure: Self.insideExpectThrows(Syntax(node))
        ))
    }

    /// ¿La llamada está dentro de `#expect(throws: ...) { ... }` o `#require(throws: ...)`?
    private static func insideExpectThrows(_ node: Syntax) -> Bool {
        var current = node.parent
        while let n = current {
            if let macro = n.as(MacroExpansionExprSyntax.self),
               ["expect", "require"].contains(macro.macroName.text),
               macro.arguments.contains(where: { $0.label?.text == "throws" }) {
                return true
            }
            if n.is(FunctionDeclSyntax.self) { return false }
            current = n.parent
        }
        return false
    }

    private func rootFact(for node: FunctionCallExprSyntax) -> RootFact? {
        let callee = node.calledExpression
        let text = node.trimmedDescription.split(separator: "\n").first.map(String.init) ?? ""

        if let ref = callee.as(DeclReferenceExprSyntax.self),
           ["expectGraph", "expectWhenCondition"].contains(ref.baseName.text) {
            let unlabeled = node.arguments.filter { $0.label == nil }
            var root = RootFact(
                kind: ref.baseName.text == "expectGraph" ? .expectGraph : .expectWhenCondition,
                modules: literalTypes(unlabeled.map(\.expression)),
                loc: loc(node),
                text: text
            )
            applyChain(from: node, to: &root)
            return root
        }

        guard let member = callee.as(MemberAccessExprSyntax.self) else { return nil }
        let name = member.declName.baseName.text
        let base = member.base.map { TypeName.stripSelf($0.trimmedDescription) }

        switch name {
        case "root" where base == "ScopeContainer" || base == "DaggerSwift.ScopeContainer":
            guard let arg = node.arguments.first(where: { $0.label?.text == "modules" }) else { return nil }
            return RootFact(kind: .root, modules: literalArray(arg.expression), loc: loc(node), text: text)

        case "buildGraph":
            guard let base, base.first?.isUppercase == true else { return nil }
            let extras = node.arguments.first(where: { $0.label?.text == "including" }).map { literalArray($0.expression) } ?? []
            return RootFact(kind: .buildGraph, modules: extras.map { [base] + $0 }, receiverModule: base, loc: loc(node), text: text)

        case "resolve":
            // `Modulo.resolve(T.self, including: [...])`: grafo compartido del módulo.
            guard let base, base.first?.isUppercase == true, base != "ScopeContainer",
                  let first = node.arguments.first, first.label == nil,
                  first.expression.trimmedDescription.hasSuffix(".self") else { return nil }
            let extras = node.arguments.first(where: { $0.label?.text == "including" }).map { literalArray($0.expression) } ?? []
            var root = RootFact(kind: .moduleResolve, modules: extras.map { [base] + $0 }, receiverModule: base, loc: loc(node), text: text)
            root.requested = [RootFact.Requested(type: TypeName.stripSelf(first.expression.trimmedDescription), loc: loc(node))]
            return root

        case "whenResolved":
            guard let base, base.first?.isUppercase == true,
                  let first = node.arguments.first else { return nil }
            var root = RootFact(kind: .whenResolved, modules: [base], receiverModule: base, loc: loc(node), text: text)
            root.provided = [TypeName.stripSelf(first.expression.trimmedDescription)]
            applyChain(from: node, to: &root)
            return root

        case "makeChildScope":
            guard let scopeArg = node.arguments.first(where: { $0.label?.text == "for" }) else { return nil }
            let scope = TypeName.stripSelf(scopeArg.expression.trimmedDescription)
            let extras = node.arguments.first(where: { $0.label?.text == "modules" }).map { literalArray($0.expression) } ?? []
            var parent: Int?
            if let receiver = member.base {
                if let ref = receiver.as(DeclReferenceExprSyntax.self) {
                    parent = rootVariables[ref.baseName.text]
                } else if let call = Self.unwrapCall(receiver) {
                    parent = rootIndexByCall[call.id]
                }
            }
            // El scope también registra sus recetas si es un @Module (se resuelve en la validación).
            return RootFact(kind: .childScope, modules: extras.map { [scope] + $0 }, parent: parent, loc: loc(node), text: text)

        default:
            return nil
        }
    }

    /// Recorre `.dependency(T.self).unresolvedFailure()`, `.resolved(T.self)`, `.whenResolved(T.self)` encadenados.
    private func applyChain(from node: FunctionCallExprSyntax, to root: inout RootFact) {
        var steps: [(name: String, type: String?, loc: Loc)] = []
        var current = Syntax(node)
        while let member = current.parent?.as(MemberAccessExprSyntax.self),
              member.base.map({ Syntax($0).id }) == current.id,
              let call = member.parent?.as(FunctionCallExprSyntax.self),
              Syntax(call.calledExpression).id == Syntax(member).id {
            let arg = call.arguments.first?.expression.trimmedDescription
            let type = arg.flatMap { $0.hasSuffix(".self") ? TypeName.stripSelf($0) : nil }
            steps.append((member.declName.baseName.text, type, loc(call)))
            current = Syntax(call)
        }
        var lastRequested: String?
        for step in steps {
            switch step.name {
            case "whenResolved":
                if let t = step.type { root.provided.append(t) }
            case "dependency", "resolved":
                if let t = step.type {
                    root.requested.append(RootFact.Requested(type: t, loc: step.loc))
                    lastRequested = t
                }
            case "unresolvedFailure":
                if let t = lastRequested {
                    root.expectedMissing.append(t)
                    root.requested.removeAll { $0.type == t }
                }
            default:
                break
            }
        }
    }

    private func literalTypes(_ exprs: [ExprSyntax]) -> [String]? {
        var out: [String] = []
        for e in exprs {
            let t = e.trimmedDescription
            guard t.hasSuffix(".self") else { return nil }
            out.append(TypeName.stripSelf(t))
        }
        return out
    }

    private func literalArray(_ expr: ExprSyntax) -> [String]? {
        guard let arr = expr.as(ArrayExprSyntax.self) else { return nil }
        return literalTypes(arr.elements.map(\.expression))
    }

    private static func unwrapCall(_ expr: ExprSyntax) -> FunctionCallExprSyntax? {
        if let call = expr.as(FunctionCallExprSyntax.self) { return call }
        if let t = expr.as(TryExprSyntax.self) { return unwrapCall(t.expression) }
        if let a = expr.as(AwaitExprSyntax.self) { return unwrapCall(a.expression) }
        return nil
    }

    // MARK: - Helpers de atributos

    private func attrName(_ element: AttributeListSyntax.Element) -> String? {
        guard let a = element.as(AttributeSyntax.self) else { return nil }
        let raw = a.attributeName.trimmedDescription
        let base = raw.split(separator: "<").first.map(String.init) ?? raw
        return base.split(separator: ".").last.map(String.init)
    }

    private func attribute(named name: String, in list: AttributeListSyntax) -> AttributeSyntax? {
        for element in list where attrName(element) == name {
            return element.as(AttributeSyntax.self)
        }
        return nil
    }

    private func labeledArgumentExpr(_ label: String, of attr: AttributeSyntax) -> ExprSyntax? {
        attr.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == label })?.expression
    }

    private func labeledArgument(_ label: String, of attr: AttributeSyntax) -> String? {
        labeledArgumentExpr(label, of: attr)?.trimmedDescription
    }
}
