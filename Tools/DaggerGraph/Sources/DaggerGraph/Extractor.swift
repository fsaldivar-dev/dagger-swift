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
    private let lines: [String]
    private var typeStack: [String] = []
    /// Paralelo a `typeStack`: `true` si ese nivel es un `@AppCompose` / `@Compose`.
    private var composeMarks: [Bool] = []
    /// Compositores abiertos (nombre calificado) y el índice de su `RootFact`, para anidar `@Compose`.
    private var composeNames: [String] = []
    private var composeRootIndex: [Int] = []
    private(set) var facts = FileFacts()

    init(tree: SourceFileSyntax, fileName: String) {
        self.converter = SourceLocationConverter(fileName: fileName, tree: tree)
        self.lines = tree.description.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        super.init(viewMode: .sourceAccurate)
    }

    private var inCompositor: Bool { composeMarks.contains(true) }

    private func popType() {
        typeStack.removeLast()
        if composeMarks.removeLast() {
            composeNames.removeLast()
            composeRootIndex.removeLast()
        }
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
    override func visitPost(_ node: StructDeclSyntax) { popType() }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        handleType(name: node.name.text, attributes: node.attributes, members: node.memberBlock, node: node)
    }
    override func visitPost(_ node: ClassDeclSyntax) { popType() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        handleType(name: node.name.text, attributes: node.attributes, members: node.memberBlock, node: node)
    }
    override func visitPost(_ node: ActorDeclSyntax) { popType() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        handleType(name: node.name.text, attributes: node.attributes, members: node.memberBlock, node: node)
    }
    override func visitPost(_ node: EnumDeclSyntax) { popType() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        typeStack.append(node.extendedType.trimmedDescription)
        composeMarks.append(false)
        return .visitChildren
    }
    override func visitPost(_ node: ExtensionDeclSyntax) { popType() }

    private func handleType(
        name: String,
        attributes: AttributeListSyntax,
        members: MemberBlockSyntax,
        node: some SyntaxProtocol
    ) -> SyntaxVisitorContinueKind {
        typeStack.append(name)
        let qualified = typeStack.joined(separator: ".")

        // Compositores: @AppCompose(M.self) (raíz) y @Compose(S.self) (scope hijo, anidado en su padre).
        let appCompose = attribute(named: "AppCompose", in: attributes)
        let compose = appCompose ?? attribute(named: "Compose", in: attributes)
        composeMarks.append(compose != nil)
        if let compose,
           let target = compose.arguments?.as(LabeledExprListSyntax.self)?.first
               .map({ TypeName.stripSelf($0.expression.trimmedDescription) }) {
            let isApp = appCompose != nil
            let composeMembers = composeMembers(members)
            facts.composes.append(ComposeFact(
                name: qualified, kind: isApp ? .app : .scope, target: target,
                parent: composeNames.last, members: composeMembers, loc: loc(node)
            ))
            var root = RootFact(
                kind: isApp ? .root : .childScope, modules: [target],
                parent: isApp ? nil : composeRootIndex.last, loc: loc(node),
                text: "\(isApp ? "@AppCompose" : "@Compose")(\(target).self) \(name)"
            )
            root.requested = composeMembers.map { RootFact.Requested(type: $0.type, loc: $0.loc) }
            facts.roots.append(root)
            composeNames.append(qualified)
            composeRootIndex.append(facts.roots.count - 1)
        }

        if let inject = attribute(named: "Inject", in: attributes) {
            // Lint 5.10: @Inject genera `Self(...)`, que en una clase no final exige `required init`.
            if let cls = Syntax(node).as(ClassDeclSyntax.self),
               !cls.modifiers.contains(where: { $0.name.text == "final" }) {
                lint(.injectNonFinal, cls.name, type: qualified)
            }
            // Lint 5.10: `let x: T = .init()` confunde a la macro con el init del tipo.
            for member in members.members {
                guard let v = member.decl.as(VariableDeclSyntax.self) else { continue }
                for b in v.bindings {
                    guard let call = b.initializer?.value.as(FunctionCallExprSyntax.self),
                          let callee = call.calledExpression.as(MemberAccessExprSyntax.self),
                          callee.base == nil, callee.declName.baseName.text == "init" else { continue }
                    lint(.injectDotInit, b, type: qualified)
                }
            }
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

    // MARK: - Compositores

    /// Los `let` sin valor inicial del compositor; `Provider<T>` se registra como `T` con `isProvider`.
    private func composeMembers(_ members: MemberBlockSyntax) -> [ComposeFact.Member] {
        var out: [ComposeFact.Member] = []
        for member in members.members {
            guard let v = member.decl.as(VariableDeclSyntax.self) else { continue }
            if v.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) { continue }
            for b in v.bindings {
                guard let t = b.typeAnnotation?.type, b.initializer == nil, b.accessorBlock == nil else { continue }
                var type = t
                var isProvider = false
                if let id = t.as(IdentifierTypeSyntax.self), id.name.text == "Provider",
                   let arg = id.genericArgumentClause?.arguments.first {
                    type = arg.argument; isProvider = true
                } else if let m = t.as(MemberTypeSyntax.self), m.name.text == "Provider",
                          let arg = m.genericArgumentClause?.arguments.first {
                    type = arg.argument; isProvider = true
                }
                out.append(ComposeFact.Member(
                    name: b.pattern.trimmedDescription,
                    type: TypeName.normalize(type.trimmedDescription),
                    isProvider: isProvider,
                    loc: loc(b)
                ))
            }
        }
        return out
    }

    // MARK: - Sitios de lint

    private func lint(_ kind: LintSite.Kind, _ node: some SyntaxProtocol, type: String? = nil) {
        let l = loc(node)
        let text = node.trimmedDescription.split(separator: "\n").first.map(String.init) ?? ""
        facts.lint.append(LintSite(
            kind: kind, text: text, loc: l, inCompositor: inCompositor, type: type,
            allowed: allowedRules(line: l.line)
        ))
    }

    /// `// dagger-graph: allow regla-a regla-b — motivo` en la misma línea o en la anterior.
    /// Devuelve las reglas nombradas (`[]` = todas); `nil` si no hay comentario.
    private func allowedRules(line: Int) -> [String]? {
        for i in [line - 1, line - 2] where i >= 0 && i < lines.count {
            guard let range = lines[i].range(of: "dagger-graph: allow") else { continue }
            let rest = lines[i][range.upperBound...]
            var rules: [String] = []
            for token in rest.split(whereSeparator: { $0.isWhitespace }) {
                let t = String(token)
                // Fin de la lista: un separador o el inicio de una explicación.
                if t.hasPrefix("—") || t.hasPrefix("-") || t.hasPrefix("//") || t.hasPrefix("(") || t.hasPrefix(":") { break }
                guard t.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." }) else { break }
                rules.append(t)
            }
            return rules
        }
        return nil
    }

    /// 5.5: `try? x.resolve(...)` / `try? compose.openX()`.
    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        if node.questionOrExclamationMark?.text == "?" {
            let text = node.expression.trimmedDescription
            if text.contains(".resolve(") || text.range(of: #"\.open[A-Z]\w*\("#, options: .regularExpression) != nil {
                lint(.optionalTry, node)
            }
        }
        return .visitChildren
    }

    /// 5.6: `catch GraphError…` / `catch let e as GraphError`.
    override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        if node.catchItems.trimmedDescription.contains("GraphError") {
            lint(.graphErrorCatch, node.catchKeyword)
        }
        return .visitChildren
    }

    /// 5.2: `ScopeContainer` como parámetro.
    override func visit(_ node: FunctionParameterSyntax) -> SyntaxVisitorContinueKind {
        if TypeName.normalize(node.type.trimmedDescription).hasSuffix("ScopeContainer") {
            lint(.containerUse, node, type: "ScopeContainer")
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

            // Lint 5.7: `@Singleton static func theme() -> Theme { .shared }`: el grafo no crea nada.
            if kind == .singleton || kind == .scoped,
               let statements = fn.body?.statements, statements.count == 1,
               let only = statements.first?.item.trimmedDescription,
               only.range(of: #"^(try\s+)?\.?(\w+\.)*shared$"#, options: .regularExpression) != nil {
                lint(.sharedReturn, fn.name, type: "\(module).\(fn.name.text)()")
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
        let isStatic = node.modifiers.contains(where: { ["static", "class"].contains($0.name.text) })
        for binding in node.bindings {
            // Lint 5.2: `let graph: ScopeContainer` fuera de un compositor.
            if let t = binding.typeAnnotation?.type,
               TypeName.normalize(t.trimmedDescription).hasSuffix("ScopeContainer") {
                lint(.containerUse, binding, type: "ScopeContainer")
            }
            // Lint 5.8: `static let compose = (try!)? AppCompose()`: el validador comprueba que sea un compositor.
            if isStatic, let value = binding.initializer?.value, let call = Self.unwrapCall(value),
               let callee = call.calledExpression.as(DeclReferenceExprSyntax.self),
               callee.baseName.text.first?.isUppercase == true {
                lint(.staticTypeInit, binding, type: callee.baseName.text)
            }
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
                  let value = binding.initializer?.value,
                  let call = Self.unwrapCall(value),
                  let index = rootIndexByCall[call.id] else { continue }
            rootVariables[name] = index
        }
    }

    /// Post-orden: la llamada interna (`ScopeContainer.root(...)`) se registra antes que la externa
    /// (`.makeChildScope(...)`), así el hijo encuentra a su padre.
    /// Service locator: `algo.register(service: x as T)` y `algo.shared.resolve()` / `resolve(T.self)`.
    private func recordLocatorUse(_ node: FunctionCallExprSyntax) -> Bool {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else { return false }
        let name = member.declName.baseName.text
        let text = node.trimmedDescription.split(separator: "\n").first.map(String.init) ?? ""
        if name == "register", let arg = node.arguments.first(where: { $0.label?.text == "service" }) {
            facts.locatorRegistrations.append(LocatorUse(type: Self.declaredType(of: arg.expression, in: node), loc: loc(node), text: text))
            return true
        }
        guard name == "resolve", let base = member.base?.trimmedDescription, base.hasSuffix(".shared") else { return false }
        var type: String?
        if let first = node.arguments.first, first.expression.trimmedDescription.hasSuffix(".self") {
            type = TypeName.stripSelf(first.expression.trimmedDescription)
        } else {
            type = Self.contextualType(of: Syntax(node))
        }
        facts.locatorRequests.append(LocatorUse(type: type, loc: loc(node), text: text))
        return true
    }

    /// `x as T` → T; `variable` con `let variable: T = ...` en la misma función → T.
    private static func declaredType(of expr: ExprSyntax, in node: FunctionCallExprSyntax) -> String? {
        if let cast = expr.as(AsExprSyntax.self) { return TypeName.normalize(cast.type.trimmedDescription) }
        if let seq = expr.as(SequenceExprSyntax.self), let last = seq.elements.last?.as(TypeExprSyntax.self) {
            return TypeName.normalize(last.type.trimmedDescription)
        }
        guard let ref = expr.as(DeclReferenceExprSyntax.self) else { return nil }
        var current = Syntax(node).parent
        while let n = current, !n.is(FunctionDeclSyntax.self) { current = n.parent }
        guard let fn = current else { return nil }
        for token in fn.tokens(viewMode: .sourceAccurate) where token.text == ref.baseName.text {
            if let binding = token.parent?.parent?.as(PatternBindingSyntax.self),
               let annotated = binding.typeAnnotation?.type {
                return TypeName.normalize(annotated.trimmedDescription)
            }
        }
        return nil
    }

    /// Tipo esperado por el contexto: `param: T = X.resolve()` o `let x: T = X.resolve()`.
    private static func contextualType(of node: Syntax) -> String? {
        var current = node.parent
        while let n = current {
            if let param = n.as(FunctionParameterSyntax.self) {
                // `x: @autoclosure @escaping () -> T = X.shared.resolve()` pide un T.
                var t = param.type.as(AttributedTypeSyntax.self)?.baseType ?? param.type
                if let fn = t.as(FunctionTypeSyntax.self), fn.parameters.isEmpty { t = fn.returnClause.type }
                return TypeName.normalize(t.trimmedDescription)
            }
            if let binding = n.as(PatternBindingSyntax.self) {
                return binding.typeAnnotation.map { TypeName.normalize($0.type.trimmedDescription) }
            }
            if n.is(CodeBlockItemSyntax.self) || n.is(MemberBlockItemSyntax.self) { return nil }
            current = n.parent
        }
        return nil
    }

    override func visitPost(_ node: FunctionCallExprSyntax) {
        if recordLocatorUse(node) { return }
        // Lint 5.1 / 5.3: `.resolve(T.self)` (argumento tipo, sin etiqueta) o `.resolve()` sobre un receptor
        // que parece un contenedor. `Color.resolve(in:)` y similares (argumento etiquetado) no cuentan.
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self),
           member.declName.baseName.text == "resolve",
           !(member.base?.trimmedDescription.hasSuffix(".shared") ?? false) {
            let base = member.base?.trimmedDescription ?? ""
            let first = node.arguments.first
            let typeArgument = first.map { $0.label == nil && $0.expression.trimmedDescription.hasSuffix(".self") } ?? false
            let containerReceiver = ["graph", "container", "scope"].contains { base.lowercased().hasSuffix($0) }
            if typeArgument || (first == nil && containerReceiver) {
                let argType = first.map { TypeName.stripSelf($0.expression.trimmedDescription) }
                if base.first?.isUppercase == true, !base.contains("(") {
                    lint(.moduleStaticResolve, node, type: TypeName.stripSelf(base))
                } else {
                    lint(.resolveCall, node, type: argType)
                }
            }
        }
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
        if let f = expr.as(ForceUnwrapExprSyntax.self) { return unwrapCall(f.expression) }
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
