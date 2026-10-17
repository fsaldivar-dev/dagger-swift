//
//  Module.swift
//  DaggerSwift
//
//  Created by Saldivar on 18/10/24.
//  Evolved to DaggerSwift v2 (Declarative Macros + DAG Engine) on 16/10/26.
//
import Foundation

@MainActor
public protocol Modulable: GraphScope { }

@MainActor
public protocol Component {
    associatedtype Module: Modulable
    static var module: Module.Type { get }
}

public extension Component {
    static var module: Module.Type { Module.self }
}

@MainActor
public final class SingletonContainer {
    public static let shared = SingletonContainer()
    private var instances: [String: Any] = [:]

    public init() {}

    public func resolve<T>(_ type: T.Type, initializer: @MainActor () -> T) -> T {
        let key = String(reflecting: T.self)
        if let instance = instances[key] as? T {
            return instance
        } else {
            let newInstance = initializer()
            instances[key] = newInstance
            return newInstance
        }
    }

    public func reset() {
        instances.removeAll()
    }
}

// MARK: - DaggerSwift v1 & v2 Unified Macros

/// Dagger 1: `@Singleton(MyServiceImpl()) static var myService: MyService`
@attached(accessor)
public macro Singleton<T>(_ wrappedValue: @autoclosure @escaping @MainActor () -> T) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "LegacySingletonAccessorMacro"
)

/// Dagger 1 (sintaxis original con etiqueta): `@Singleton(wrappedValue: MyServiceImpl())`
@attached(accessor)
public macro Singleton<T>(wrappedValue: @autoclosure @escaping @MainActor () -> T) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "LegacySingletonAccessorMacro"
)

/// Dagger 1 (sintaxis original con etiqueta): `@Provider(wrappedValue: OtherServiceImpl())`
@attached(accessor)
public macro Provider<T>(wrappedValue: @autoclosure @escaping @MainActor () -> T) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "LegacyProviderAccessorMacro"
)

/// Dagger 2: `@Singleton static func apiClient() -> any ApiClient` dentro de `@Module`
@attached(peer)
public macro Singleton() = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "PeerMarkerMacro"
)

/// Dagger 1: `@Provider(OtherServiceImpl()) static var otherService: OtherService`
@attached(accessor)
public macro Provider<T>(_ wrappedValue: @autoclosure @escaping @MainActor () -> T) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "LegacyProviderAccessorMacro"
)

/// Dagger 2: `@Provider static func useCase(...) -> UseCase` dentro de `@Module`
@attached(peer)
public macro Provider() = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "PeerMarkerMacro"
)

/// Dagger 2: Ata una dependencia al Scope del `@Module` donde está declarada.
@attached(peer)
public macro Scoped() = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "PeerMarkerMacro"
)

/// Dagger 2: Ata una dependencia a un `GraphScope` o `Precondition` explícito (ej. `@Scoped(ValidatedSession.self)`).
@attached(peer)
public macro Scoped<S: GraphScope>(_ scope: S.Type) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "PeerMarkerMacro"
)

/// Dagger 2: Declara un Nodo de Regla de Negocio (Feature Flag / migración progresiva A -> B) en el grafo.
@attached(peer)
public macro BusinessRule() = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "PeerMarkerMacro"
)

/// Dagger 2: Declara un Nodo de Precondición (ej. `ValidatedSession`) que bloquea el sub-grafo si no se cumple.
@attached(peer)
public macro Precondition(_ reason: String = "Precondición requerida no satisfecha") = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "PeerMarkerMacro"
)

/// Dagger 2: Convierte una estructura o enumeración en un Módulo del Grafo (`GraphScope`, `GraphModule`, `Modulable`)
/// y genera en tiempo de compilación el registro topológico de sus nodos `@Singleton`, `@Scoped`, `@Provider`, `@BusinessRule` y `@Precondition`.
/// Soporta `includes: [ModuleV1.self]` para heredar los providers y el Scope de una versión anterior (`V1 -> V2`).
@attached(member, names: arbitrary)
@attached(extension, conformances: GraphScope, GraphModule, Modulable, names: arbitrary)
public macro Module(includes: [any GraphModule.Type] = []) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "ModuleMacro"
)

/// Dagger 2: Variante de `@Module` que asocia el módulo a un `GraphScope` compartido (ej. `@Module(scope: PaymentsScope.self)`
/// para variantes hermanas como México, Argentina y Colombia), de modo que los hijos con `@Inject(scope: PaymentsScope.self)`
/// funcionen indistintamente con cualquiera de las variantes activas.
@attached(member, names: arbitrary)
@attached(extension, conformances: GraphScope, GraphModule, Modulable, names: arbitrary)
public macro Module<S: GraphScope>(scope: S.Type, includes: [any GraphModule.Type] = []) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "ModuleMacro"
)

/// Dagger 2: Declara un `@Module` con versión explícita en la paleta del grafo: `@Module(0.1)`, `@Module(1.0)`, `@Module(2.0)`.
@attached(member, names: arbitrary)
@attached(extension, conformances: GraphScope, GraphModule, Modulable, names: arbitrary)
public macro Module(_ version: Double, includes: [any GraphModule.Type] = []) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "ModuleMacro"
)

/// Dagger 2: Declara un `@Module` con versión explícita (`@Module(0.1, scope: ...)`, `@Module(1.0, scope: ...)`, `@Module(2.0, scope: ...)`).
@attached(member, names: arbitrary)
@attached(extension, conformances: GraphScope, GraphModule, Modulable, names: arbitrary)
public macro Module<S: GraphScope>(_ version: Double, scope: S.Type, includes: [any GraphModule.Type] = []) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "ModuleMacro"
)

/// Dagger 2: Genera automáticamente el `init` limpio (para Unit Tests sin grafo) y el cableado de resolución en el grafo.
@attached(member, names: arbitrary)
@attached(extension, conformances: Injectable, names: arbitrary)
public macro Inject() = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "InjectMacro"
)

/// Dagger 2: Genera automáticamente el `init` limpio y ata el ciclo de vida de la clase al Scope indicado (`@Inject(scope: RepoDetailModule.self)`).
@attached(member, names: arbitrary)
@attached(extension, conformances: Injectable, names: arbitrary)
public macro Inject<S: GraphScope>(scope: S.Type) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "InjectMacro"
)
