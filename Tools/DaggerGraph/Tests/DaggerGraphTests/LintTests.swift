//
//  LintTests.swift
//  Extractor + validador + linter sobre fixtures en memoria (sin tocar disco).
//

import Testing
import SwiftParser
@testable import DaggerGraph

private func facts(_ files: [String: String]) -> [(file: String, facts: FileFacts)] {
    files.sorted { $0.key < $1.key }.map { name, source in
        (name, FactExtractor.extract(from: Parser.parse(source: source), fileName: name))
    }
}

private func diagnostics(_ files: [String: String], lint: LintConfig? = LintConfig(lint: true)) -> [Diagnostic] {
    var v = Validator(facts: facts(files))
    v.lintConfig = lint
    return v.run()
}

private func messages(_ d: [Diagnostic]) -> [String] { d.map(\.rendered) }

private let modules = """
import DaggerSwift
final class Theme {}
final class User { init(theme: Theme) {} }
final class Draft { init(user: User) {} }
protocol Layout {}
struct Classic: Layout {}
struct Session: Precondition { let id: String }
final class Auth { var id: String? }

@Module
enum AppModule {
    @Singleton static func theme() -> Theme { Theme() }
    @Singleton static func auth() -> Auth { Auth() }
    @BusinessRule static func layout() -> any Layout { Classic() }
}

@Module
enum SessionModule {
    @Precondition("sin sesión") static func session(auth: Auth) -> Session? { auth.id.map(Session.init) }
    @Scoped static func user(theme: Theme) -> User { User(theme: theme) }
    @Provider static func draft(user: User) -> Draft { Draft(user: user) }
}
"""

@Suite("@AppCompose / @Compose en dagger-graph")
struct ComposeRootTests {

    @Test("Un compositor raíz y su hijo se extraen como raíces de composición anidadas")
    func composeFacts() {
        let f = facts(["Compose.swift": modules + """
        @AppCompose(AppModule.self)
        final class Compose {
            let theme: Theme
            @Compose(SessionModule.self)
            struct AccountSession {
                let session: Session
                let user: User
                let draft: Provider<Draft>
            }
        }
        """])[0].facts
        #expect(f.composes.map(\.name) == ["Compose", "Compose.AccountSession"])
        #expect(f.composes[0].kind == .app && f.composes[0].target == "AppModule")
        #expect(f.composes[1].kind == .scope && f.composes[1].parent == "Compose")
        #expect(f.composes[1].members.map(\.type) == ["Session", "User", "Draft"])
        #expect(f.composes[1].members.map(\.isProvider) == [false, false, true])
        #expect(f.roots.count == 2)
        #expect(f.roots[1].kind == .childScope && f.roots[1].parent == 0)
        #expect(f.roots[1].requested.map(\.type) == ["Session", "User", "Draft"])
    }

    @Test("La validación por raíz cubre al compositor: binding faltante y scope nunca abierto")
    func rootValidation() {
        let d = diagnostics(["Compose.swift": modules + """
        @AppCompose(AppModule.self)
        final class Compose {
            let theme: Theme
            let user: User                 // User es @Scoped en SessionModule: la raíz nunca abre ese scope
            @Compose(SessionModule.self)
            struct AccountSession {
                let missing: Missing       // nadie lo provee
            }
        }
        """], lint: nil)
        let m = messages(d)
        #expect(m.contains { $0.contains("error") && $0.contains("'Missing'") && $0.contains("@Compose(SessionModule.self) AccountSession") })
        // SessionModule solo se registra en el hijo: desde la raíz, 'User' no existe (no es scopeNotActive, es faltante).
        #expect(m.contains { $0.contains("error") && $0.contains("'User' requerido por el compositor") && $0.contains("[AppModule]") })
    }
}

@Suite("dagger-graph lint")
struct LintTests {

    @Test("5.11: @Provider / @BusinessRule como `let`, y @Singleton como Provider<T>")
    func providerAsLet() {
        let d = diagnostics(["Compose.swift": modules + """
        @AppCompose(AppModule.self)
        final class Compose {
            let theme: Provider<Theme>
            let layout: any Layout
            @Compose(SessionModule.self)
            struct AccountSession {
                let draft: Draft
                let user: User
            }
        }
        """])
        let m = messages(d)
        #expect(m.contains { $0.contains("error: [lint provider-as-let]") && $0.contains("let draft: Draft") })
        #expect(m.contains { $0.contains("error: [lint provider-as-let]") && $0.contains("let layout: Layout") })
        #expect(m.contains { $0.contains("warning: [lint let-as-provider]") && $0.contains("Provider<Theme>") })
        #expect(!m.contains { $0.contains("lint") && $0.contains("let user: User") })
    }

    @Test("5.1, 5.2, 5.5, 5.6 en una feature; nada de eso dentro del compositor")
    func featureRules() {
        let d = diagnostics([
            "Compose.swift": modules + """
            @AppCompose(AppModule.self)
            final class Compose {
                let theme: Theme
                func custom(container: ScopeContainer) throws -> Theme { try container.resolve(Theme.self) }
            }
            """,
            "Feature.swift": """
            import DaggerSwift
            struct FeatureView {
                func load(container: ScopeContainer) {
                    let a = try? container.resolve(Theme.self)
                    do { _ = try container.resolve(Theme.self) } catch GraphError.unmetPrecondition { } catch { }
                }
            }
            """,
        ])
        let feature = messages(d).filter { $0.hasPrefix("Feature.swift") }
        #expect(feature.contains { $0.contains("error: [lint resolve-outside-compositor]") })
        #expect(feature.contains { $0.contains("warning: [lint container-in-feature]") })
        #expect(feature.contains { $0.contains("error: [lint optional-try]") })
        #expect(feature.contains { $0.contains("warning: [lint catch-outside-root]") })
        #expect(!messages(d).contains { $0.hasPrefix("Compose.swift") && $0.contains("[lint") })
    }

    @Test("5.3, 5.4, 5.7, 5.8, 5.10")
    func otherRules() {
        let d = diagnostics([
            "Compose.swift": modules + """
            @AppCompose(AppModule.self)
            final class Compose { let theme: Theme }
            """,
            "Bad.swift": """
            import DaggerSwift
            enum Globals {
                static let compose = try! Compose()
                static func theme() throws -> Theme { try AppModule.resolve(Theme.self) }
                static func register(in c: ScopeContainer) { c.bindInstance(Theme(), as: Theme.self) }
            }
            @Module
            enum LegacyModule {
                @Singleton static func theme() -> Theme { .shared }
                @Scoped static func other() -> Theme { Theme.shared }
            }
            @Inject
            class NotFinal {
                let theme: Theme
                let helper: Helper = .init()
            }
            final class Helper {}
            """,
        ])
        let m = messages(d).filter { $0.hasPrefix("Bad.swift") }
        #expect(m.contains { $0.contains("error: [lint static-compositor]") })
        #expect(m.contains { $0.contains("error: [lint module-static-resolve]") })
        #expect(m.contains { $0.contains("warning: [lint dynamic-registration]") })
        #expect(m.filter { $0.contains("warning: [lint shared-in-module]") }.count == 2)
        #expect(m.contains { $0.contains("error: [lint inject-non-final]") })
        #expect(m.contains { $0.contains("warning: [lint inject-dot-init]") })
    }

    @Test("Supresión inline, severidad configurable y archivos raíz")
    func suppressionAndConfig() {
        let files = [
            "Compose.swift": modules + """
            @AppCompose(AppModule.self)
            final class Compose { let theme: Theme }
            """,
            "Coordinator.swift": """
            import DaggerSwift
            struct Coordinator {
                func open(container: ScopeContainer) {
                    // dagger-graph: allow resolve-outside-compositor
                    _ = try? container.resolve(Theme.self)
                    do { _ = try container.resolve(Theme.self) } catch let e as GraphError { _ = e } // dagger-graph: allow resolve-outside-compositor
                }
            }
            """,
        ]
        let strict = messages(diagnostics(files))
        #expect(!strict.contains { $0.contains("[lint resolve-outside-compositor]") })
        let bridge = messages(diagnostics(["Bridge.swift": """
        import DaggerSwift
        final class Bridge {
            func install(c: ScopeContainer, t: Theme) {
                // dagger-graph: allow dynamic-registration — puente temporal
                c.bindInstance(t, as: Theme.self)
                c.bindInstance(t, as: Theme.self)
            }
        }
        """]))
        #expect(bridge.filter { $0.contains("[lint dynamic-registration]") }.count == 1)
        #expect(strict.contains { $0.contains("[lint optional-try]") })
        #expect(strict.contains { $0.contains("[lint catch-outside-root]") })
        #expect(strict.contains { $0.contains("[lint container-in-feature]") })

        var config = LintConfig(lint: true)
        config.rootFiles = ["Coordinator.swift"]
        config.rules = ["optional-try": "warning", "container-in-feature": "off"]
        let relaxed = messages(diagnostics(files, lint: config))
        #expect(!relaxed.contains { $0.contains("[lint catch-outside-root]") })
        #expect(relaxed.contains { $0.contains("warning: [lint optional-try]") })
        #expect(!relaxed.contains { $0.contains("[lint container-in-feature]") })
    }

    @Test("locator-resolve: `X.shared.resolve()` cuenta como locator (5.1), también en defaults de init")
    func locatorResolve() {
        let d = diagnostics(["Locator.swift": """
        import DaggerSwift
        final class Container { static let shared = Container(); func resolve<T>() -> T { fatalError() } }
        final class ThemeManager {}
        final class Screen {
            let theme: ThemeManager
            init(theme: ThemeManager = Container.shared.resolve()) { self.theme = theme }
            func flags() -> Bool { (Container.shared.resolve() as ThemeManager) === theme }
        }
        """])
        let m = messages(d).filter { $0.contains("[lint locator-resolve]") }
        #expect(m.count == 2)
        #expect(m.allSatisfy { $0.contains("warning:") })
    }

    @Test("`Color.resolve(in:)` y otros `resolve` ajenos no cuentan; sin lint no hay hallazgos")
    func noFalsePositives() {
        let files = ["View.swift": """
        import SwiftUI
        struct ThemedView {
            func colors(theme: Theme) {
                let tint = theme.tint.resolve(in: .init())
                let any = resolver.resolve()
            }
        }
        """]
        #expect(messages(diagnostics(files)).isEmpty)
        #expect(messages(diagnostics(files, lint: nil)).isEmpty)
    }
}
