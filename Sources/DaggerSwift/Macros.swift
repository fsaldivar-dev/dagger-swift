//
//  Macros.swift
//  DaggerSwift
//
//  Target fuente DELGADO: solo declaraciones de macros + re-export del runtime.
//  Las macros no pueden distribuirse como binario en SwiftPM, así que en el paquete de
//  release `DaggerSwiftCore` es un XCFramework y este archivo (más `DaggerSwiftMacros`)
//  se compila siempre desde fuente (<1 s, cero dependencias externas).
//  Las expansiones usan `DaggerSwift.ScopeContainer`, `DaggerSwift.Injectable`, etc.:
//  la búsqueda calificada por módulo atraviesa el `@_exported import`.
//

@_exported import DaggerSwiftCore

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


/// Sintetiza automáticamente en un `GraphScope` el enumerador `Palette` (`ModulePalette`)
/// y el selector estático `module(for:)` en tiempo de compilación (estilo `CodingKeys`).
@attached(member, names: arbitrary)
public macro Scope<Contract>(
    of contract: Contract.Type,
    v0_1: Any.Type,
    v1_0: Any.Type,
    v2_0: Any.Type
) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "ModulePaletteMacro"
)

/// Dagger 2: Genera automáticamente el `init` limpio (para Unit Tests y resolución explícita en compile-time) y el cableado del grafo.
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

// MARK: - RootComposer: @AppCompose / @Compose (resolución jerárquica)

/// Compositor raíz (*RootComposer*): la única pieza de la app que abre el grafo y resuelve de él.
///
/// ```swift
/// @MainActor
/// @AppCompose(AppModule.self)
/// final class AppCompose {
///   let theme: Theme                      // nivel app: se resuelve en init(); si falta, init lanza
///   @Compose(SessionModule.self)
///   struct Session {                      // scope hijo: openSession() lo abre, close() lo cierra
///     let currentAccount: CurrentAccount  // @Scoped del módulo de sesión
///     @Compose(EditorModule.self)
///     struct Editor { ... }               // sub-sub-scope: session.openEditor()
///   }
/// }
/// ```
/// Genera `graph`, `init() throws` (abre la raíz con el módulo indicado y resuelve cada `let`),
/// `close()` y un `openX() throws -> X` por cada tipo anidado marcado con `@Compose`.
/// Las propiedades con valor inicial no se piden al grafo. Un `init` propio desactiva el generado.
@attached(member, names: arbitrary)
public macro AppCompose<M: GraphModule>(_ module: M.Type) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "AppComposeMacro"
)

/// Nivel hijo del compositor (`AppCompose` → `Compose` → `Compose` …): abre un scope del grafo bajo el
/// contenedor del padre y resuelve sus `let` de ahí. Genera `graph`, `init(parent:) throws`, `close()`
/// y `openX()` por cada `@Compose` anidado. Si un `let` es una `@Precondition` no cumplida, `init` lanza
/// `GraphError.unmetPrecondition` antes de construir nada.
@attached(member, names: arbitrary)
public macro Compose<S: GraphScope>(_ scope: S.Type) = #externalMacro(
    module: "DaggerSwiftMacros",
    type: "ComposeMacro"
)
