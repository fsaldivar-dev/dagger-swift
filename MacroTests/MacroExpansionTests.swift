//
//  MacroExpansionTests.swift
//  Tests de expansión de @Inject / @Module SIN swift-syntax: se le pasa al plugin el mismo
//  mensaje JSON que manda el compilador (HostToPluginMessage.expandAttachedMacro) y se revisa
//  el código expandido y los diagnósticos. Equivalente a assertMacroExpansion.
//

import Testing
@testable import DaggerSwiftMacros

private struct Expansion {
    let source: String
    let diagnostics: [[String: Any]]
}

private func expand(_ macro: String, role: String = "member", attribute: String, decl: String, offset: Int = 100) -> Expansion {
    let payload: [String: Any] = [
        "macro": ["moduleName": "DaggerSwiftMacros", "typeName": macro, "name": attribute],
        "macroRole": role,
        "attributeSyntax": ["source": attribute],
        "declSyntax": ["source": decl, "location": ["fileName": "Fixture.swift", "offset": offset, "line": 1, "column": 1]],
    ]
    let result = DaggerSwiftMacrosPlugin.handleExpandAttachedMacro(payload)["expandMacroResult"] as? [String: Any] ?? [:]
    return Expansion(
        source: result["expandedSource"] as? String ?? "",
        diagnostics: result["diagnostics"] as? [[String: Any]] ?? []
    )
}

@Suite("Expansión de macros (protocolo del plugin, sin swift-syntax)")
struct MacroExpansionTests {

    @Test("@Inject con stored properties: init limpio + register con provide")
    func injectStoredProperties() {
        let e = expand("InjectMacro", attribute: "@Inject", decl: """
        @Inject
        struct UseCase {
            let repository: any Repository
            let flags: Flags
            var cache: Int = 0
        }
        """)
        #expect(e.source.contains("public init(repository: any Repository, flags: Flags)"))
        #expect(e.source.contains("container.provide(Self.self)"))
        #expect(!e.source.contains("cache"))
        #expect(e.diagnostics.isEmpty)
    }

    @Test("let a, b: Int → ambos parámetros Int")
    func multipleBindings() {
        let e = expand("InjectMacro", attribute: "@Inject", decl: """
        @Inject
        struct Pair {
            let a, b: Int
            let name: String, count: Int
        }
        """)
        #expect(e.source.contains("public init(a: Int, b: Int, name: String, count: Int)"))
    }

    @Test("init con default: el parámetro no se pide al grafo")
    func initWithDefault() {
        let e = expand("InjectMacro", attribute: "@Inject", decl: """
        @Inject
        final class Client {
            let dep: Dep
            let retries: Int
            init(dep: Dep, retries: Int = 3) { self.dep = dep; self.retries = retries }
        }
        """)
        #expect(e.source.contains("self.init(dep: try container.resolve(Dep.self))"))
        #expect(!e.source.contains("retries: try"))
        #expect(e.source.contains("public convenience init(from container"))
    }

    @Test("@MainActor del tipo → onMainActor; @MainActor de un miembro → no")
    func mainActorDetection() {
        let typeLevel = expand("InjectMacro", attribute: "@Inject", decl: """
        @MainActor
        @Inject
        final class ViewModel {
            let dep: Dep
        }
        """)
        #expect(typeLevel.source.contains("ScopeContainer.onMainActor"))

        let memberLevel = expand("InjectMacro", attribute: "@Inject", decl: """
        @Inject
        final class Repository: Sendable {
            @MainActor private var session: Session? = nil
        }
        """)
        #expect(!memberLevel.source.contains("onMainActor"))
    }

    @Test("La palabra class dentro de un struct no genera convenience init")
    func classWordInStruct() {
        let e = expand("InjectMacro", attribute: "@Inject", decl: """
        @Inject
        struct Labels {
            let dep: Dep
            var text: String { "subclass" }
        }
        """)
        #expect(e.source.contains("public init(from container"))
        #expect(!e.source.contains("convenience"))
    }

    @Test("@Module: @Singleton, @Scoped sin scope (usa el módulo) y tipos con closures genéricas")
    func moduleRegistration() {
        let e = expand("ModuleMacro", attribute: "@Module", decl: """
        @Module
        enum AppModule {
            @Singleton
            static func api() -> any ApiClient { Api() }

            @Scoped
            static func repo(api: any ApiClient) -> Repo { Repo(api: api) }

            @Singleton
            static func box() -> Box<(Int, String) -> Bool> { Box() }
        }
        """)
        #expect(e.source.contains("container.provideSingleton((any ApiClient).self)"))
        #expect(e.source.contains("container.provideScoped(in: Self.self, Repo.self) { (api: any ApiClient) in"))
        #expect(e.source.contains("(Box<(Int, String) -> Bool>).self"))
    }

    @Test("@Module @MainActor: las funciones se construyen vía onMainActor (salvo nonisolated)")
    func mainActorModule() {
        let e = expand("ModuleMacro", attribute: "@Module", decl: """
        @MainActor
        @Module
        enum AppModule {
            @Singleton
            static func theme() -> Theme { .shared }
            @Provider
            nonisolated static func name() -> String { "x" }
        }
        """)
        #expect(e.source.contains("try DaggerSwift.ScopeContainer.onMainActor { Self.theme() }"))
        #expect(e.source.contains("        Self.name()"))
    }

    @Test("@Module: función async → diagnóstico claro en la posición de la función")
    func asyncFunctionDiagnostic() {
        let decl = """
        @Module
        enum AsyncModule {
            @Singleton
            static func dep() async -> Dep { Dep() }
        }
        """
        let e = expand("ModuleMacro", attribute: "@Module", decl: decl, offset: 1_000)
        #expect(e.diagnostics.count == 1)
        let message = e.diagnostics.first?["message"] as? String ?? ""
        #expect(message.contains("no puede ser async"))
        let position = e.diagnostics.first?["position"] as? [String: Any]
        let expectedOffset = 1_000 + decl.utf8.distance(from: decl.startIndex, to: decl.range(of: "func dep")!.lowerBound)
        #expect(position?["offset"] as? Int == expectedOffset)
        #expect(!e.source.contains("dep()"))
    }

    @Test("@Module: función sin tipo de retorno → diagnóstico")
    func missingReturnTypeDiagnostic() {
        let e = expand("ModuleMacro", attribute: "@Module", decl: """
        @Module
        enum M {
            @Singleton
            static func nothing() { }
        }
        """)
        #expect((e.diagnostics.first?["message"] as? String ?? "").contains("necesita un tipo de retorno"))
    }

    // MARK: - Diagnósticos de prácticas (Quick Start §5)

    @Test("5.10: @Inject en una clase no final es un error; `.init(` como default, un warning")
    func injectDiagnostics() {
        let e = expand("InjectMacro", attribute: "@Inject", decl: """
        @Inject
        class NotFinal {
            let dep: Dep
            let helper: Helper = .init()
        }
        """)
        let severities = e.diagnostics.compactMap { $0["severity"] as? String }
        #expect(severities.contains("error"))
        #expect(severities.contains("warning"))
        #expect(e.diagnostics.contains { ($0["message"] as? String)?.contains("final") == true })
        #expect(e.diagnostics.contains { ($0["message"] as? String)?.contains(".init(") == true })

        let ok = expand("InjectMacro", attribute: "@Inject", decl: """
        @Inject
        final class Fine {
            let dep: Dep
            let helper = Helper()
        }
        """)
        #expect(ok.diagnostics.isEmpty)
    }

    @Test("5.7: @Module que devuelve .shared avisa; con `// dagger-graph: allow shared-in-module` calla")
    func moduleSharedDiagnostics() {
        let e = expand("ModuleMacro", attribute: "@Module", decl: """
        @Module
        enum AppModule {
            @Singleton static func theme() -> Theme { .shared }
            @Singleton static func prefs() -> Prefs { Prefs.shared }  // dagger-graph: allow shared-in-module
            @Singleton static func api() -> Api { Api() }
        }
        """)
        let warnings = e.diagnostics.filter { ($0["severity"] as? String) == "warning" }
        #expect(warnings.count == 1)
        #expect((warnings.first?["message"] as? String)?.contains("theme()") == true)
        #expect(e.source.contains("provideSingleton"))
    }
}
