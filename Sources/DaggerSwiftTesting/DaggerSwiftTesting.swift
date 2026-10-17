//
//  DaggerSwiftTesting.swift
//  DaggerSwiftTesting
//
//  DSL Declarativo (Sugar) para validar la composición de grafos, Fakes y precondiciones con `import Testing`:
//
//  ShowcaseCoreModule
//      .whenResolved((any GitHubRepositoryProtocol).self).returns(FakerGitHubRepository.self)
//      .resolved(GetProfileUseCase.self)
//      .resolved(GetRepositoriesUseCase.self)
//
//  expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
//      .resolved(GetProfileUseCase.self)
//      .resolved(FeedViewModel.self)
//

import Foundation
import Testing
import DaggerSwift

// MARK: - 1. Tags para filtrar tests en Xcode

public extension Tag {
    @Tag static var graph: Self
    @Tag static var precondition: Self
    @Tag static var businessRule: Self
}

// MARK: - 2. Extensión directa en cualquier `@Module`: `Module.whenResolved(Protocol.self).returns(Fake.self)`

public extension GraphModule {
    /// Inicia un grafo de prueba para este módulo inyectando un Fake cuando se solicite `ProtocolType`.
    static func whenResolved<ProtocolType>(_ protocolType: ProtocolType.Type) -> WhenResolvedBuilder<ProtocolType> {
        let expectation = expectGraph(Self.self)
        return expectation.whenResolved(protocolType)
    }
}

/// Builder intermedio para `whenResolved(Protocol.self).returns(Fake.self)`.
public struct WhenResolvedBuilder<ProtocolType> {
    public let expectation: GraphExpectation

    /// Registra un tipo `@Inject` (ej. `FakerGitHubRepository.self`) como respuesta para `ProtocolType`.
    @discardableResult
    public func returns<Fake: Injectable>(
        _ fakeType: Fake.Type,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> GraphExpectation {
        let container = expectation.container
        container.provideSingleton(ProtocolType.self) {
            guard let instance = try container.resolve(Fake.self) as? ProtocolType else {
                Issue.record(
                    Comment(rawValue: "❌ '\(Fake.self)' no conforma el protocolo '\(ProtocolType.self)'"),
                    sourceLocation: sourceLocation
                )
                throw GraphError.unregisteredDependency(
                    type: String(reflecting: ProtocolType.self),
                    searchedFromScope: container.scopeID
                )
            }
            return instance
        }
        return expectation
    }

    /// Alias con backticks por si se escribe `.return(Fake.self)`.
    @discardableResult
    public func `return`<Fake: Injectable>(
        _ fakeType: Fake.Type,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> GraphExpectation {
        returns(fakeType, sourceLocation: sourceLocation)
    }

    /// Registra una instancia directa (ej. `FakerGitHubRepository()`) como respuesta para `ProtocolType`.
    @discardableResult
    public func returns(_ instance: @autoclosure @escaping () -> ProtocolType) -> GraphExpectation {
        expectation.container.provideSingleton(ProtocolType.self) {
            instance()
        }
        return expectation
    }

    /// Alias con backticks por si se escribe `.return(FakerGitHubRepository())`.
    @discardableResult
    public func `return`(_ instance: @autoclosure @escaping () -> ProtocolType) -> GraphExpectation {
        returns(instance())
    }
}

// MARK: - 3. Puntos de Entrada del DSL Declarativo

/// Inicia la validación declarativa de un grafo compuesto por uno o más `@Module`.
@discardableResult
public func expectGraph(_ modules: any GraphModule.Type...) -> GraphExpectation {
    let container = ScopeContainer.root(modules: modules)
    return GraphExpectation(container: container)
}

/// Inicia la validación de un grafo ejecutando primero una condición (ej. iniciar sesión o activar un Feature Flag).
@discardableResult
public func expectWhenCondition<D>(
    _ modules: any GraphModule.Type...,
    sourceLocation: SourceLocation = #_sourceLocation,
    condition: (D) throws -> Void
) -> GraphExpectation {
    let container = ScopeContainer.root(modules: modules)
    let expectation = GraphExpectation(container: container)
    return expectation.when(sourceLocation: sourceLocation, condition)
}

// MARK: - 4. Cadena Fluida `GraphExpectation`

public final class GraphExpectation {
    public let container: ScopeContainer
    private var stepsLog: [String] = []

    public init(container: ScopeContainer, stepsLog: [String] = []) {
        self.container = container
        self.stepsLog = stepsLog
    }

    /// Permite encadenar `.whenResolved(Protocol.self).returns(Fake.self)` dentro de `expectGraph(...)`.
    public func whenResolved<ProtocolType>(_ protocolType: ProtocolType.Type) -> WhenResolvedBuilder<ProtocolType> {
        WhenResolvedBuilder(expectation: self)
    }

    /// Verifica que el tipo `T` se pueda resolver exitosamente en el grafo actual.
    @discardableResult
    public func resolved<T>(
        _ type: T.Type,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Self {
        let name = Self.shortName(String(reflecting: type))
        do {
            _ = try container.resolve(type)
            stepsLog.append("✅ .resolved(\(name).self)")
        } catch {
            let trace = container.lastFailureTrace.map(Self.shortName).joined(separator: " -> ❌ ")
            let msg = "❌ No se pudo resolver '\(name)'. Camino roto: [\(trace)] — \(error)"
            stepsLog.append(msg)
            Issue.record(Comment(rawValue: msg), sourceLocation: sourceLocation)
        }
        return self
    }

    /// Verifica que el tipo `T` además cumpla una validación sobre la instancia resuelta (útil para `@BusinessRule`).
    @discardableResult
    public func resolved<T>(
        _ type: T.Type,
        sourceLocation: SourceLocation = #_sourceLocation,
        where predicate: (T) -> Bool
    ) -> Self {
        let name = Self.shortName(String(reflecting: type))
        do {
            let instance = try container.resolve(type)
            if predicate(instance) {
                stepsLog.append("✅ .resolved(\(name).self) cumplió la condición")
            } else {
                let msg = "❌ '\(name)' se resolvió pero no cumplió la condición esperada en el bloque 'where'"
                stepsLog.append(msg)
                Issue.record(Comment(rawValue: msg), sourceLocation: sourceLocation)
            }
        } catch {
            let trace = container.lastFailureTrace.map(Self.shortName).joined(separator: " -> ❌ ")
            let msg = "❌ No se pudo resolver '\(name)'. Camino roto: [\(trace)] — \(error)"
            stepsLog.append(msg)
            Issue.record(Comment(rawValue: msg), sourceLocation: sourceLocation)
        }
        return self
    }

    /// Verifica que `T` esté bloqueado por una `@Precondition` (ej. `ValidatedSession.self`).
    @discardableResult
    public func blocked<T, P: Precondition>(
        _ type: T.Type,
        by precondition: P.Type,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Self {
        let targetName = Self.shortName(String(reflecting: type))
        let precondName = Self.shortName(String(reflecting: precondition))

        do {
            _ = try container.resolve(type)
            let msg = "❌ Se esperaba que '\(targetName)' estuviera bloqueado por '\(precondName)', pero se resolvió."
            stepsLog.append(msg)
            Issue.record(Comment(rawValue: msg), sourceLocation: sourceLocation)
        } catch let GraphError.unmetPrecondition(failedType, reason) {
            if failedType.contains(precondName) {
                stepsLog.append("🔒 .blocked(\(targetName).self, by: \(precondName).self) -> Bloqueado correctamente (\(reason))")
            } else {
                let msg = "❌ '\(targetName)' se bloqueó por '\(failedType)', pero se esperaba '\(precondName)'."
                stepsLog.append(msg)
                Issue.record(Comment(rawValue: msg), sourceLocation: sourceLocation)
            }
        } catch {
            let msg = "❌ '\(targetName)' falló con un error distinto a @Precondition: \(error)"
            stepsLog.append(msg)
            Issue.record(Comment(rawValue: msg), sourceLocation: sourceLocation)
        }
        return self
    }

    /// Verifica que `T` NO se pueda resolver porque falta registrar una dependencia o módulo en el grafo.
    @discardableResult
    public func unresolved<T>(
        _ type: T.Type,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Self {
        let name = Self.shortName(String(reflecting: type))
        do {
            _ = try container.resolve(type)
            let msg = "❌ Se esperaba que '\(name)' fallara por dependencia faltante, pero se resolvió."
            stepsLog.append(msg)
            Issue.record(Comment(rawValue: msg), sourceLocation: sourceLocation)
        } catch {
            let trace = container.lastFailureTrace.map(Self.shortName).joined(separator: " -> ❌ ")
            stepsLog.append("🛑 .unresolved(\(name).self) -> Falló como se esperaba: [\(trace)]")
        }
        return self
    }

    /// Ejecuta una acción sobre una dependencia del grafo (ej. iniciar sesión o cambiar un Feature Flag)
    /// para validar cómo cambia la resolución en los siguientes pasos de la cadena.
    @discardableResult
    public func when<D>(
        sourceLocation: SourceLocation = #_sourceLocation,
        _ action: (D) throws -> Void
    ) -> Self {
        let depName = Self.shortName(String(reflecting: D.self))
        do {
            let dep = try container.resolve(D.self)
            try action(dep)
            stepsLog.append("⚡ .when(\(depName)) ejecutado")
        } catch {
            let msg = "❌ Falló el bloque .when(\(depName)): \(error)"
            stepsLog.append(msg)
            Issue.record(Comment(rawValue: msg), sourceLocation: sourceLocation)
        }
        return self
    }

    /// Abre un sub-scope hijo (ej. `RepoDetailModule.self`) opcionalmente inyectando un valor runtime (`bindInstance`).
    @discardableResult
    public func inChildScope<S: GraphScope>(
        _ scope: S.Type,
        modules: [any GraphModule.Type] = []
    ) -> GraphExpectation {
        let child = container.makeChildScope(for: scope, modules: modules)
        stepsLog.append("📂 .inChildScope(\(Self.shortName(S.scopeID.name)).self)")
        return GraphExpectation(container: child, stepsLog: stepsLog)
    }

    /// Abre un sub-scope hijo e inyecta un valor runtime (`bindInstance`).
    @discardableResult
    public func inChildScope<S: GraphScope, V>(
        _ scope: S.Type,
        binding value: V,
        modules: [any GraphModule.Type] = []
    ) -> GraphExpectation {
        let child = container.makeChildScope(for: scope, modules: modules)
        child.bindInstance(value)
        stepsLog.append("📂 .inChildScope(\(Self.shortName(S.scopeID.name)).self, binding: \(Self.shortName(String(reflecting: V.self))))")
        return GraphExpectation(container: child, stepsLog: stepsLog)
    }

    /// Verifica que al ejecutar `teardown()` en este scope, todas las instancias se liberen con 0 fugas de memoria.
    @discardableResult
    public func tornDownCleanly(
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> Self {
        let leaks = container.teardown()
        if leaks.isEmpty {
            stepsLog.append("🧹 .tornDownCleanly() -> 0 fugas en RAM")
        } else {
            let msg = "❌ Fuga de memoria detectada en teardown(): \(leaks.joined(separator: ", "))"
            stepsLog.append(msg)
            Issue.record(Comment(rawValue: msg), sourceLocation: sourceLocation)
        }
        return self
    }

    private static func shortName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "any ", with: "")
            .split(separator: ".")
            .last
            .map(String.init) ?? raw
    }
}
