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
                    deps: injectDependencies(members)
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
            moduleBindings(members, module: qualified, moduleScope: moduleScope)
        }
        return .visitChildren
    }

    // MARK: - @Inject

    private func injectDependencies(_ members: MemberBlockSyntax) -> [Dependency] {
        if let initDecl = members.members.lazy.compactMap({ $0.decl.as(InitializerDeclSyntax.self) }).first {
            return initDecl.signature.parameterClause.parameters.map {
                Dependency(type: TypeName.normalize($0.type.trimmedDescription), loc: loc($0))
            }
        }
        var deps: [Dependency] = []
        for member in members.members {
            guard let v = member.decl.as(VariableDeclSyntax.self) else { continue }
            if v.modifiers.contains(where: { ["static", "class"].contains($0.name.text) }) { continue }
            let skipAttrs = ["Published", "State", "Binding"]
            if v.attributes.contains(where: { attrName($0).map(skipAttrs.contains) ?? false }) { continue }
            for b in v.bindings {
                guard b.initializer == nil, b.accessorBlock == nil, let t = b.typeAnnotation?.type else { continue }
                deps.append(Dependency(type: TypeName.normalize(t.trimmedDescription), loc: loc(b)))
            }
        }
        return deps
    }

    // MARK: - @Module

    private func moduleBindings(_ members: MemberBlockSyntax, module: String, moduleScope: String?) {
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

            var provides = TypeName.normalize(ret.trimmedDescription)
            if kind == .precondition, provides.hasSuffix("?") { provides.removeLast() }

            facts.bindings.append(
                Binding(
                    provides: provides,
                    kind: kind,
                    lifetime: lifetime,
                    origin: "\(module).\(fn.name.text)()",
                    loc: loc(fn.name),
                    deps: fn.signature.parameterClause.parameters.map {
                        Dependency(type: TypeName.normalize($0.type.trimmedDescription), loc: loc($0))
                    }
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
