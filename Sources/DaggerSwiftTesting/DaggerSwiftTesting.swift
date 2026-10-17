//
//  DaggerSwiftTesting.swift
//  DaggerSwiftTesting
//
//  DSL Declarativo para validar la composición de grafos y precondiciones con `import Testing`:
//
//  1. Validar que un flujo se resuelva:
//     expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
//         .resolved(GetProfileUseCase.self)
//         .resolved(GetRepositoriesUseCase.self)
//         .resolved(FeedViewModel.self)
//
//  2. Validar precondiciones sin navegar sub-scopes manualmente:
//     expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self, RepoDetailModule.self)
//         .whenResolved(GitHubRepoItem.self).returns(.flagshipDaggerRepo)
//         .dependency(RepoDetailInspector.self).preconditionFailure()
//         .when { (auth: any AuthRepositoryProtocol) in
//             auth.loginAsSaldivar()
//         }
//         .dependency(RepoDetailInspector.self).resolved()
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
    /// Inicia un grafo de prueba para este módulo inyectando un Fake o valor cuando se solicite `ProtocolType`.
    static func whenResolved<ProtocolType>(_ protocolType: ProtocolType.Type) -> WhenResolvedBuilder<ProtocolType> {
        let expectation = expectGraph(Self.self)
        return expectation.whenResolved(protocolType)
    }
}

/// Builder para `.whenResolved(Protocol.self).returns(Fake.self)`.
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
                    Comment(rawValue: "❌ '\(Fake.self)' no implementa '\(ProtocolType.self)'"),
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

    @discardableResult
    public func `return`<Fake: Injectable>(
        _ fakeType: Fake.Type,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> GraphExpectation {
        returns(fakeType, sourceLocation: sourceLocation)
    }

    /// Registra una instancia o valor directo (ej. `.flagshipDaggerRepo` o `FakerGitHubRepository()`) para `ProtocolType`.
    @discardableResult
    public func returns(_ instance: @autoclosure @escaping () -> ProtocolType) -> GraphExpectation {
        expectation.container.provideSingleton(ProtocolType.self) {
            instance()
        }
        return expectation
    }

    @discardableResult
    public func `return`(_ instance: @autoclosure @escaping () -> ProtocolType) -> GraphExpectation {
        returns(instance())
    }
}

// MARK: - 3. Selector `.dependency(Type.self)` con Expectativas Explícitas

/// Permite expresar qué se espera de una dependencia específica:
/// `.dependency(RepoDetailInspector.self).preconditionFailure()`
/// `.dependency(RepoDetailInspector.self).resolved()`
/// `.dependency(GetProfileUseCase.self).unresolvedFailure()`
public struct DependencyExpectation<T> {
    public let expectation: GraphExpectation

    /// Verifica que la dependencia se resuelva exitosamente en el grafo.
    @discardableResult
    public func resolved(sourceLocation: SourceLocation = #_sourceLocation) -> GraphExpectation {
        expectation.resolved(T.self, sourceLocation: sourceLocation)
    }

    /// Verifica que la dependencia se resuelva y cumpla una condición (útil para `@BusinessRule`).
    @discardableResult
    public func resolved(
        sourceLocation: SourceLocation = #_sourceLocation,
        where predicate: (T) -> Bool
    ) -> GraphExpectation {
        expectation.resolved(T.self, sourceLocation: sourceLocation, where: predicate)
    }

    /// Verifica que la dependencia NO se resuelva porque una `@Precondition` de su árbol devolvió `nil`.
    /// Si la dependencia ni siquiera tiene `@Precondition` en su sub-grafo, falla indicando que no aplica.
    @discardableResult
    public func preconditionFailure(
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> GraphExpectation {
        let targetName = GraphExpectation.shortName(String(reflecting: T.self))
        let preconditions = expectation.container.preconditionsInSubgraph(for: T.self)
            .map(GraphExpectation.shortName)

        guard !preconditions.isEmpty else {
            Issue.record(
                Comment(rawValue: "❌ '\(targetName)' NO tiene ninguna @Precondition en su árbol de dependencias, por lo que no puede evaluarse con preconditionFailure()."),
                sourceLocation: sourceLocation
            )
            return expectation
        }

        do {
            _ = try expectation.container.resolve(T.self)
            Issue.record(
                Comment(rawValue: "❌ Se esperaba preconditionFailure() en '\(targetName)' (protegido por \(preconditions)), pero se resolvió exitosamente."),
                sourceLocation: sourceLocation
            )
        } catch let GraphError.unmetPrecondition(failedType, reason) {
            expectation.recordStep("🔒 .dependency(\(targetName).self).preconditionFailure() -> Bloqueado por \(GraphExpectation.shortName(failedType)) (\(reason))")
        } catch {
            Issue.record(
                Comment(rawValue: "❌ '\(targetName)' (protegido por \(preconditions)) falló por un error distinto a @Precondition: \(error)"),
                sourceLocation: sourceLocation
            )
        }
        return expectation
    }

    /// Verifica que la dependencia NO se resuelva específicamente por la `@Precondition` indicada.
    @discardableResult
    public func preconditionFailure<P: Precondition>(
        _ precondition: P.Type,
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> GraphExpectation {
        let targetName = GraphExpectation.shortName(String(reflecting: T.self))
        let precondName = GraphExpectation.shortName(String(reflecting: P.self))
        let preconditions = expectation.container.preconditionsInSubgraph(for: T.self)
            .map(GraphExpectation.shortName)

        guard preconditions.contains(precondName) else {
            Issue.record(
                Comment(rawValue: "❌ '\(targetName)' no depende de la @Precondition '\(precondName)'. Precondiciones en su árbol: \(preconditions)"),
                sourceLocation: sourceLocation
            )
            return expectation
        }

        return expectation.blocked(T.self, by: precondition, sourceLocation: sourceLocation)
    }

    /// Verifica estáticamente (sin instanciar nada) que esta dependencia NO requiere ninguna `@Precondition` en su árbol.
    @discardableResult
    public func hasNoPreconditions(
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> GraphExpectation {
        let targetName = GraphExpectation.shortName(String(reflecting: T.self))
        let preconditions = expectation.container.preconditionsInSubgraph(for: T.self)
            .map(GraphExpectation.shortName)
        if !preconditions.isEmpty {
            Issue.record(
                Comment(rawValue: "❌ Se esperaba que '\(targetName)' fuera libre de precondiciones, pero depende de: \(preconditions)"),
                sourceLocation: sourceLocation
            )
        } else {
            expectation.recordStep("✅ .dependency(\(targetName).self).hasNoPreconditions()")
        }
        return expectation
    }

    /// Verifica que la dependencia falle porque falta registrar un módulo o dependencia en el grafo.
    @discardableResult
    public func unresolvedFailure(
        sourceLocation: SourceLocation = #_sourceLocation
    ) -> GraphExpectation {
        expectation.unresolved(T.self, sourceLocation: sourceLocation)
    }
}

// MARK: - 4. Puntos de Entrada `expectGraph` y `expectWhenCondition`

/// Construye el grafo activando automáticamente los Scopes de todos los `@Module` pasados,
/// sin necesidad de navegar manualmente con `inChildScope`.
@discardableResult
public func expectGraph(_ modules: any GraphModule.Type...) -> GraphExpectation {
    return GraphExpectation(modules: modules)
}

/// Construye el grafo y ejecuta primero una condición (ej. iniciar sesión o cambiar un Feature Flag).
@discardableResult
public func expectWhenCondition<D>(
    _ modules: any GraphModule.Type...,
    sourceLocation: SourceLocation = #_sourceLocation,
    condition: (D) throws -> Void
) -> GraphExpectation {
    let expectation = GraphExpectation(modules: modules)
    return expectation.when(sourceLocation: sourceLocation, condition)
}

// MARK: - 5. Cadena Fluida `GraphExpectation`

public final class GraphExpectation {
    public let container: ScopeContainer
    private var stepsLog: [String] = []

    public init(container: ScopeContainer, stepsLog: [String] = []) {
        self.container = container
        self.stepsLog = stepsLog
    }

    public convenience init(modules: [any GraphModule.Type]) {
        // Registramos los módulos en la raíz y activamos sus Scopes en cadena
        // para que cualquier @Scoped de los módulos listados funcione sin llamar a inChildScope.
        let root = ScopeContainer.root(modules: modules)
        var current = root
        for module in modules {
            current = current.makeChildScope(for: module)
        }
        self.init(container: current)
    }

    /// Selecciona una dependencia para validar su comportamiento (`.resolved()`, `.preconditionFailure()`, `.unresolvedFailure()`).
    public func dependency<T>(_ type: T.Type) -> DependencyExpectation<T> {
        DependencyExpectation(expectation: self)
    }

    /// Inyecta un Fake o valor cuando se solicite `ProtocolType`.
    public func whenResolved<ProtocolType>(_ protocolType: ProtocolType.Type) -> WhenResolvedBuilder<ProtocolType> {
        WhenResolvedBuilder(expectation: self)
    }

    /// Verifica directamente que `T` se resuelva sin errores.
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

    /// Verifica que `T` se resuelva y cumpla una condición.
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
                let msg = "❌ '\(name)' se resolvió pero no cumplió la condición esperada"
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

    /// Verifica que `T` esté bloqueado por la `@Precondition` indicada.
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
                stepsLog.append("🔒 .blocked(\(targetName).self, by: \(precondName).self) (\(reason))")
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

    /// Verifica que `T` falle por falta de registro en el grafo.
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
            stepsLog.append("🛑 .unresolved(\(name).self) -> [\(trace)]")
        }
        return self
    }

    /// Ejecuta un cambio de estado sobre una dependencia del grafo (ej. hacer login o cambiar un flag).
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

    fileprivate func recordStep(_ text: String) {
        stepsLog.append(text)
    }

    fileprivate static func shortName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "any ", with: "")
            .split(separator: ".")
            .last
            .map(String.init) ?? raw
    }
}
