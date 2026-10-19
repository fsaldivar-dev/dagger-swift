//
//  ScopeContainer.swift
//  DaggerSwift
//
//  Created by Saldivar on 16/10/26.
//

import Foundation
#if canImport(ObjectiveC)
import ObjectiveC
#endif

/// Contrato para módulos de DaggerSwift v2 que registran sus nodos de Dominio, Negocio y Precondiciones
/// en un `ScopeContainer`. Funciona en SwiftUI, UIKit, AppKit, Background Actors y CLIs.
public protocol GraphModule: GraphScope {
    static var moduleVersion: String { get }
    static func register(in container: ScopeContainer)
}

public extension GraphModule {
    static var moduleVersion: String { "1.0" }

    /// Resuelve cualquier componente `@Inject` o dependencia registrada directamente desde el `@Module`,
    /// sin necesidad de instanciar ni manipular `ScopeContainer` en el código de la aplicación.
    static func resolve<T>(
        _ type: T.Type = T.self,
        including extraModules: [any GraphModule.Type] = []
    ) throws -> T {
        let scope = ScopeContainer.sharedRuntimeScope(for: Self.self, including: extraModules)
        return try scope.resolve(type)
    }

    /// Libera las instancias `@Scoped` asociadas a este `@Module` y devuelve los nombres de posibles fugas de memoria.
    @discardableResult
    static func teardownScope() -> [String] {
        ScopeContainer.teardownSharedRuntimeScope(for: Self.self)
    }
}

/// Tipo marcado con `@Inject`: sabe registrarse a sí mismo en el grafo.
/// El motor lo registra Just-In-Time la primera vez que alguien lo pide,
/// así las cadenas `ViewModel -> UseCase -> Repository` se resuelven sin registro manual.
public protocol Injectable {
    static func register(in container: ScopeContainer)
}

/// Token RAII que ejecuta `container.teardown()` automáticamente en su `deinit`.
/// Permite atar la vida de un `ScopeContainer` a cualquier `UIViewController`, `Coordinator` o controlador.
public final class ScopeLifetimeToken: @unchecked Sendable {
    private let container: ScopeContainer

    public init(container: ScopeContainer) {
        self.container = container
    }

    deinit {
        container.teardown()
    }
}

/// Registro de tokens de `autoTeardown` para plataformas sin runtime de Objective-C.
/// Guarda el token mientras el dueño (referencia débil) siga vivo; `drain()` suelta los tokens
/// de dueños muertos, lo que ejecuta `teardown()` en su `deinit`.
final class OwnerTokenRegistry: @unchecked Sendable {
    static let shared = OwnerTokenRegistry()

    private struct Entry {
        weak var owner: AnyObject?
        let token: ScopeLifetimeToken
    }

    private let lock = NSLock()
    /// Serializa las purgas completas (incluido el teardown) para que `drain()` sea determinista:
    /// al volver, cualquier purga concurrente ya terminó de cerrar sus scopes. Recursivo porque
    /// `onScopeTeardown` puede volver a crear scopes.
    private let drainLock = NSRecursiveLock()
    private var entries: [Entry] = []

    func retain(_ token: ScopeLifetimeToken, whileAlive owner: AnyObject) {
        drain()
        lock.lock()
        entries.append(Entry(owner: owner, token: token))
        lock.unlock()
    }

    @discardableResult
    func drain() -> Int {
        drainLock.lock()
        defer { drainLock.unlock() }
        lock.lock()
        guard !entries.isEmpty else {
            lock.unlock()
            return 0
        }
        var released: [ScopeLifetimeToken] = []
        entries.removeAll { entry in
            guard entry.owner == nil else { return false }
            released.append(entry.token)
            return true
        }
        lock.unlock()
        // Los tokens se sueltan fuera del lock: su deinit ejecuta teardown().
        let count = released.count
        released.removeAll()
        return count
    }
}

/// Referencia débil a un objeto para auditar en tiempo real que las instancias de un Scope
/// realmente mueren en RAM cuando se ejecuta `teardown()`.
private struct WeakObjectBox {
    let typeName: String
    weak var object: AnyObject?
}

/// Referencia débil hacia un `ScopeContainer` hijo para propagar `teardown()` hacia abajo
/// sin impedir que el hijo muera por ARC cuando su vista/controlador se cierra.
private struct WeakScopeContainer {
    weak var value: ScopeContainer?
}

/// Receta perezosa (Lazy Recipe) almacenada en el grafo.
/// No instancia nada al registrarse; solo guarda cómo construir el nodo y en qué Scope vive.
private struct GraphRecipe {
    let typeName: String
    let lifetime: NodeLifetime
    let dependencies: [String]
    let dependencyTypes: [Any.Type]
    let build: (ScopeContainer) throws -> Any
}

/// Snapshot serializable (JSON) de un nodo registrado en el grafo para inspección en tests.
public struct GraphNodeSnapshot: Codable, Sendable, Equatable {
    public let type: String
    public let kind: String
    public let ownerScope: String
    public let isInstantiated: Bool
    public let dependencies: [String]

    public init(type: String, kind: String, ownerScope: String, isInstantiated: Bool, dependencies: [String]) {
        self.type = type
        self.kind = kind
        self.ownerScope = ownerScope
        self.isInstantiated = isInstantiated
        self.dependencies = dependencies
    }
}

/// Snapshot jerárquico serializable (JSON) de un ScopeContainer y sus hijos.
public struct GraphScopeSnapshot: Codable, Sendable, Equatable {
    public let scope: String
    public let isTornDown: Bool
    public let activeInstanceCount: Int
    public let nodes: [GraphNodeSnapshot]
    public let children: [GraphScopeSnapshot]

    public init(
        scope: String,
        isTornDown: Bool,
        activeInstanceCount: Int,
        nodes: [GraphNodeSnapshot],
        children: [GraphScopeSnapshot]
    ) {
        self.scope = scope
        self.isTornDown = isTornDown
        self.activeInstanceCount = activeInstanceCount
        self.nodes = nodes
        self.children = children
    }
}

/// Motor del Grafo y Contenedor Jerárquico de Scopes (`Global` -> `Session` -> `Module`).
/// Thread-safe (`Sendable`) mediante `NSRecursiveLock` compartido por árbol:
/// puede invocarse desde `@MainActor` (SwiftUI / UIKit) o desde hilos de background, `Actor`s y CLIs.
public final class ScopeContainer: @unchecked Sendable {
    /// Identificador del Scope que representa esta caja (ej. `GlobalScope`, `ValidatedSession`, `LoansModule`).
    public let scopeID: ScopeID

    /// Indica si se auditan fugas de memoria con cajas débiles (por defecto `true`).
    public let auditLeaks: Bool

    /// Scopes adicionales compatibles con esta caja (ej. evolución `ModuleV1 -> ModuleV2` vía `includes:`
    /// o variantes hermanas `Mexico / Argentina / Colombia` vía `@Module(scope:)`).
    private var compatibleScopeIDs: Set<ScopeID> = []

    /// Referencia fuerte al contenedor padre (más longevo). `nil` únicamente en `GlobalScope`.
    public let parent: ScopeContainer?

    /// Lock recursivo compartido desde la raíz del árbol para garantizar thread-safety sin deadlocks.
    private let lock: NSRecursiveLock

    /// Contenedores hijos activos (referencia `weak` para que mueran solos cuando su pantalla se cierra).
    private var children: [WeakScopeContainer] = []

    /// Recetas registradas en este nivel del grafo (Costo cero al arrancar: son closures, no instancias).
    private var recipes: [ObjectIdentifier: GraphRecipe] = [:]

    /// Caché de recetas resueltas (evita recorrer la jerarquía de padres en cada llamada consecutiva).
    private var cachedRecipes: [ObjectIdentifier: (ScopeContainer, GraphRecipe)] = [:]

    /// Caché de cajas de Scope encontradas (evita recorrer el árbol de scopes repetidamente).
    private var cachedScopeBoxes: [ScopeID: ScopeContainer] = [:]

    /// Instancias vivas cuyo ciclo de vida pertenece exactamente a ESTE `scopeID`.
    private var instances: [ObjectIdentifier: Any] = [:]

    /// Rastreador de objetos creados en este Scope para detectar retain cycles al cerrar el Scope.
    private var leakTracker: [WeakObjectBox] = []

    /// Generación de registros del árbol (solo se usa en la raíz). Sube con cada registro o scope compatible
    /// en CUALQUIER caja, invalidando las cachés de todos los descendientes.
    private var generation: UInt64 = 0

    /// Generación con la que se llenaron las cachés de esta caja.
    private var cacheGeneration: UInt64 = 0

    /// Construcciones `@Scoped`/`@Singleton` en curso en esta caja. Las factories corren SIN lock;
    /// los demás hilos que pidan el mismo tipo esperan a que termine (doble verificación).
    private var pending: [ObjectIdentifier: PendingBuild] = [:]

    /// Caché por tipo: ¿su subgrafo estático contiene alguna `@Precondition`?
    private var subgraphHasPreconditions: [ObjectIdentifier: Bool] = [:]

    /// Raíz del árbol (`nil` si esta caja es la raíz).
    private let rootRef: ScopeContainer?

    /// Último camino de resolución donde ocurrió un error (para diagnóstico en `DaggerSwiftTesting`).
    private var lastFailurePath: [String] = []

    /// Indica si este contenedor ya fue cerrado mediante `teardown()`.
    public private(set) var isTornDown: Bool = false

    public init(
        scopeID: ScopeID = GlobalScope.scopeID,
        parent: ScopeContainer? = nil,
        auditLeaks: Bool = true
    ) {
        self.scopeID = scopeID
        self.parent = parent
        self.auditLeaks = auditLeaks
        self.lock = parent?.lock ?? NSRecursiveLock()
        self.rootRef = parent.map { $0.rootRef ?? $0 }
    }

    /// Declara que esta caja de Scope también satisface `scope` (para evolución `V1 -> V2` o variantes por país).
    public func addCompatibleScope<S: GraphScope>(_ scope: S.Type) {
        lock.lock()
        defer { lock.unlock() }
        guard self.scopeID != GlobalScope.scopeID else { return }
        compatibleScopeIDs.insert(S.scopeID)
        rootContainer.generation &+= 1
    }

    /// Crea un contenedor raíz (`GlobalScope`) opcionalmente cargando una lista de módulos base.
    public static func root(
        modules: [any GraphModule.Type] = [],
        auditLeaks: Bool = true
    ) -> ScopeContainer {
        let container = ScopeContainer(scopeID: GlobalScope.scopeID, parent: nil, auditLeaks: auditLeaks)
        for module in modules {
            module.register(in: container)
        }
        return container
    }

    private var activeChildScopes: [ScopeID: ScopeContainer] = [:]
    private static let runtimeRoot = ScopeContainer.root()

    internal static func sharedRuntimeScope<M: GraphModule>(
        for module: M.Type,
        including extraModules: [any GraphModule.Type]
    ) -> ScopeContainer {
        runtimeRoot.lock.lock()
        defer { runtimeRoot.lock.unlock() }

        let id = M.scopeID
        if let existing = runtimeRoot.activeChildScopes[id], !existing.isTornDown {
            for extra in extraModules {
                extra.register(in: existing)
            }
            return existing
        }
        let child = runtimeRoot.makeChildScope(for: module, modules: extraModules)
        runtimeRoot.activeChildScopes[id] = child
        return child
    }

    internal static func teardownSharedRuntimeScope<M: GraphModule>(for module: M.Type) -> [String] {
        runtimeRoot.lock.lock()
        defer { runtimeRoot.lock.unlock() }

        let id = M.scopeID
        guard let existing = runtimeRoot.activeChildScopes.removeValue(forKey: id) else { return [] }
        return existing.teardown()
    }

    // MARK: - Jerarquía de Scopes (Hijos) y Vínculo con UIKit / Coordinators

    /// Crea un contenedor hijo atado al Scope de un módulo o precondición.
    /// Si el tipo conforma `GraphModule`, registra automáticamente sus recetas locales.
    @discardableResult
    public func makeChildScope<S: GraphScope>(
        for scope: S.Type,
        modules: [any GraphModule.Type] = []
    ) -> ScopeContainer {
        OwnerTokenRegistry.shared.drain()
        lock.lock()
        defer { lock.unlock() }

        let child = ScopeContainer(scopeID: S.scopeID, parent: self, auditLeaks: self.auditLeaks)
        if let graphModule = scope as? any GraphModule.Type {
            graphModule.register(in: child)
        }
        for module in modules {
            module.register(in: child)
        }
        children.removeAll { $0.value == nil }
        children.append(WeakScopeContainer(value: child))
        return child
    }

    /// Ata el ciclo de vida de este `ScopeContainer` a cualquier objeto dueño (por ejemplo, un
    /// `UIViewController`, `NSViewController` o un `Coordinator` de UIKit).
    /// Cuando `owner` sale de memoria por ARC (`deinit`), este `ScopeContainer` ejecuta `teardown()` automáticamente.
    @discardableResult
    public func autoTeardown(whenDeallocated owner: AnyObject) -> ScopeLifetimeToken {
        let token = ScopeLifetimeToken(container: self)
        #if canImport(ObjectiveC) && !DAGGER_NO_OBJC
        let key = Unmanaged.passUnretained(self).toOpaque()
        // El puente a `Any` de objc_setAssociatedObject puede dejar al dueño en el autorelease pool:
        // en el hilo principal eso retrasaba su `deinit` (y el teardown) hasta el fin del run loop.
        autoreleasepool {
            objc_setAssociatedObject(owner, key, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        #else
        // Sin runtime de Objective-C (Linux/Windows) no hay hook de `deinit` del dueño:
        // el token se retiene en un registro con referencia débil al dueño y se libera
        // (disparando `teardown()`) en la siguiente purga.
        OwnerTokenRegistry.shared.retain(token, whileAlive: owner)
        #endif
        return token
    }

    /// Purga los tokens de `autoTeardown(whenDeallocated:)` cuyos dueños ya murieron y cierra sus scopes.
    /// En plataformas Apple es un no-op (el runtime de Objective-C lo hace al instante en el `deinit`).
    /// En Linux/Windows se llama sola en cada `autoTeardown` y `makeChildScope`; llámala manualmente
    /// si necesitas el cierre en un punto exacto.
    @discardableResult
    public static func drainDeallocatedOwners() -> Int {
        OwnerTokenRegistry.shared.drain()
    }

    // MARK: - 1. Registro de Nodos de Dominio (@Singleton, @Scoped, @Provider)

    /// Registra un `@Singleton` infiriendo el tipo `T` directamente de su `.init` o factory.
    public func provideSingleton<T, each D>(
        _ factory: @escaping (repeat each D) throws -> T
    ) {
        registerRecipe(for: T.self, lifetime: .singleton, factory: factory)
    }

    /// Registra un `@Singleton` para un protocolo o tipo explícito (ej. `(any ApiClient).self`).
    public func provideSingleton<T, each D>(
        _ type: T.Type,
        factory: @escaping (repeat each D) throws -> T
    ) {
        registerRecipe(for: type, lifetime: .singleton, factory: factory)
    }

    /// Registra una dependencia `@Scoped` atada explícitamente a un `GraphScope` (ej. `ValidatedSession.self`).
    public func provideScoped<S: GraphScope, T, each D>(
        in scope: S.Type,
        _ factory: @escaping (repeat each D) throws -> T
    ) {
        registerRecipe(for: T.self, lifetime: .scoped(S.scopeID), factory: factory)
    }

    /// Registra una dependencia `@Scoped` para un protocolo explícito dentro del `GraphScope` indicado.
    public func provideScoped<S: GraphScope, T, each D>(
        in scope: S.Type,
        _ type: T.Type,
        factory: @escaping (repeat each D) throws -> T
    ) {
        registerRecipe(for: type, lifetime: .scoped(S.scopeID), factory: factory)
    }

    /// Registra una dependencia `@Scoped` atada automáticamente al `scopeID` de este contenedor actual (ej. `LoansModule`).
    public func provideScoped<T, each D>(
        _ factory: @escaping (repeat each D) throws -> T
    ) {
        registerRecipe(for: T.self, lifetime: .scoped(self.scopeID), factory: factory)
    }

    /// Registra una dependencia `@Scoped` para un protocolo explícito en el `scopeID` de este contenedor actual.
    public func provideScoped<T, each D>(
        _ type: T.Type,
        factory: @escaping (repeat each D) throws -> T
    ) {
        registerRecipe(for: type, lifetime: .scoped(self.scopeID), factory: factory)
    }

    /// Registra un `@Provider` (sin caché: crea una nueva instancia cada vez que se solicita, auto-resolviendo sus parámetros).
    public func provide<T, each D>(
        _ factory: @escaping (repeat each D) throws -> T
    ) {
        registerRecipe(for: T.self, lifetime: .transient, factory: factory)
    }

    /// Registra un `@Provider` para un protocolo o tipo explícito.
    public func provide<T, each D>(
        _ type: T.Type,
        factory: @escaping (repeat each D) throws -> T
    ) {
        registerRecipe(for: type, lifetime: .transient, factory: factory)
    }

    /// Equivalente a `@BindsInstance` de Dagger: inyecta un valor de runtime (ej. el repositorio
    /// seleccionado, un ID de Deep Link) en ESTE scope, para que las clases `@Inject` lo reciban por su `init`.
    /// Muere con el scope al ejecutar `teardown()`.
    public func bindInstance<T>(_ value: T, as type: T.Type = T.self) {
        registerRecipe(for: type, lifetime: .transient) { () -> T in value }
    }

    // MARK: - 2. Registro de Nodos de Negocio (@BusinessRule / Feature Flags)

    /// Registra una regla de negocio o Feature Flag que decide dinámicamente qué variante o implementación entregar.
    public func provideBusinessRule<T, each D>(
        _ type: T.Type,
        rule: @escaping (repeat each D) throws -> T
    ) {
        registerRecipe(for: type, lifetime: .businessRule, factory: rule)
    }

    // MARK: - 3. Registro de Nodos de Precondición (@Precondition / Sesión / Deep Links)

    /// Registra una precondición de estado (ej. `ValidatedSession`).
    /// Si el validador devuelve `nil` o lanza un error cuando un componente la solicita,
    /// el grafo aborta antes de crear el componente y devuelve `GraphError.unmetPrecondition`.
    public func providePrecondition<P: Precondition, each D>(
        _ type: P.Type = P.self,
        reasonIfUnmet: String = "Precondición requerida no satisfecha",
        validator: @escaping (repeat each D) throws -> P?
    ) {
        lock.lock()
        defer { lock.unlock() }

        let key = ObjectIdentifier(type)
        let typeName = String(reflecting: type)
        var depNames: [String] = []
        var depTypes: [Any.Type] = []
        repeat depNames.append(String(reflecting: (each D).self))
        repeat depTypes.append((each D).self)

        recipes[key] = GraphRecipe(
            typeName: typeName,
            lifetime: .precondition(P.scopeID),
            dependencies: depNames,
            dependencyTypes: depTypes,
            build: { resolver in
                let result: P?
                do {
                    result = try validator(repeat try resolver.resolve((each D).self))
                } catch let graphError as GraphError {
                    throw graphError
                } catch {
                    throw GraphError.unmetPrecondition(type: typeName, reason: error.localizedDescription)
                }
                guard let validValue = result else {
                    throw GraphError.unmetPrecondition(type: typeName, reason: reasonIfUnmet)
                }
                return validValue
            }
        )
    }

    // MARK: - Motor de Resolución Topológica (DFS + Ruteo de Scopes)

    /// Resuelve un tipo `T` de forma thread-safe recorriendo el grafo en profundidad:
    /// 1. Evalúa primero TODAS las `@Precondition` del subgrafo (0 allocations si alguna falla).
    /// 2. Verifica que no existan ciclos (`A -> B -> A`), también entre hilos.
    /// 3. Busca la receta en el Scope actual o subiendo hacia los padres (`parent`).
    /// 4. Si es `@Scoped` o `@Singleton`, sube hasta la caja dueña (`findBoxUpwards`) y construye una sola vez.
    /// Las factories del usuario se ejecutan SIN el lock tomado.
    public func resolve<T>(_ type: T.Type = T.self) throws -> T {
        if type == ScopeContainer.self, let selfT = self as? T {
            return selfT
        }
        if let context = ResolutionContext.active {
            return try resolve(type, context: context)
        }
        lock.lock()
        rootContainer.lastFailurePath.removeAll(keepingCapacity: true)
        lock.unlock()
        return try ResolutionContext.run { context in
            try evaluatePreconditionsUpFront(for: type, context: context)
            return try resolve(type, context: context)
        }
    }

    private func resolve<T>(_ type: T.Type, context: ResolutionContext) throws -> T {
        if type == ScopeContainer.self, let selfT = self as? T {
            return selfT
        }
        let key = ObjectIdentifier(type)

        // 1. Detección de ciclos en la resolución actual
        if context.stack.contains(key) {
            let chain = context.names + [String(reflecting: type)]
            recordFailure(chain, overwrite: true)
            throw Self.reportProgrammerError(.circularDependency(chain: chain))
        }

        // 2. Receta en este contenedor o algún ancestro; si no existe pero el tipo es @Inject, Just-In-Time.
        guard let recipe = recipeRegisteringJustInTime(for: type, key: key) else {
            let typeName = String(reflecting: type)
            recordFailure(context.names + [typeName], overwrite: true)
            throw Self.reportProgrammerError(.unregisteredDependency(type: typeName, searchedFromScope: self.scopeID))
        }

        // 3. Ejecutar según el ciclo de vida del nodo
        switch recipe.lifetime {
        case .transient, .businessRule:
            return try build(recipe, as: type, key: key, in: self, context: context)

        case .precondition:
            if let evaluated = context.preconditionValues[key] as? T {
                return evaluated
            }
            let value = try build(recipe, as: type, key: key, in: self, context: context)
            context.preconditionValues[key] = value
            return value

        case .scoped(let targetScopeID):
            return try resolveScoped(recipe, as: type, key: key, scope: targetScopeID, context: context)
        }
    }

    /// `@Scoped` / `@Singleton`: una sola instancia por caja dueña, construida fuera del lock.
    private func resolveScoped<T>(
        _ recipe: GraphRecipe,
        as type: T.Type,
        key: ObjectIdentifier,
        scope targetScopeID: ScopeID,
        context: ResolutionContext
    ) throws -> T {
        while true {
            lock.lock()
            // Subir desde el contenedor actual para encontrar la caja dueña del Scope.
            guard let ownerBox = findBoxUpwards(matching: targetScopeID) else {
                lock.unlock()
                let typeName = String(reflecting: type)
                recordFailure(context.names + [typeName], overwrite: true)
                throw Self.reportProgrammerError(.scopeNotActive(
                    requestedScope: targetScopeID,
                    currentScope: self.scopeID,
                    dependencyType: typeName
                ))
            }
            // El scope existió pero ya se cerró: error de estado (no de programación).
            guard !ownerBox.isTornDown else {
                lock.unlock()
                let typeName = String(reflecting: type)
                recordFailure(context.names + [typeName], overwrite: true)
                throw GraphError.scopeClosed(scope: targetScopeID, dependencyType: typeName)
            }

            // Si ya existe en la caja dueña, devolverla en O(1)
            if let cached = ownerBox.instances[key] as? T {
                lock.unlock()
                return cached
            }

            // Otro hilo la está construyendo: esperar (o fallar si esperar cerraría un ciclo entre hilos).
            if let inFlight = ownerBox.pending[key] {
                lock.unlock()
                guard inFlight.wait(by: context) else {
                    let chain = context.names + [String(reflecting: type)]
                    recordFailure(chain, overwrite: true)
                    throw Self.reportProgrammerError(.circularDependency(chain: chain))
                }
                continue // ya está en caché, o el constructor falló y lo intentamos nosotros
            }

            let mine = PendingBuild(owner: context)
            ownerBox.pending[key] = mine
            lock.unlock()
            defer {
                lock.lock()
                if ownerBox.pending[key] === mine {
                    ownerBox.pending[key] = nil
                }
                lock.unlock()
                mine.finish()
            }

            // Se construye usando 'ownerBox' como resolver para garantizar la Regla de Oro:
            // un Scope padre (ej. Global) NO puede depender de cosas registradas solo en un Scope hijo.
            let instance = try build(recipe, as: type, key: key, in: ownerBox, context: context)
            lock.lock()
            if !ownerBox.isTornDown {
                ownerBox.instances[key] = instance
                ownerBox.trackForLeaksIfNeeded(instance, typeName: recipe.typeName)
            }
            lock.unlock()
            return instance
        }
    }

    /// Ejecuta la factory del usuario (sin lock) registrando el camino para ciclos y diagnóstico.
    private func build<T>(
        _ recipe: GraphRecipe,
        as type: T.Type,
        key: ObjectIdentifier,
        in resolver: ScopeContainer,
        context: ResolutionContext
    ) throws -> T {
        context.push(key, name: recipe.typeName)
        defer { context.pop() }
        do {
            guard let instance = try recipe.build(resolver) as? T else {
                throw GraphError.unregisteredDependency(type: recipe.typeName, searchedFromScope: resolver.scopeID)
            }
            return instance
        } catch {
            recordFailure(context.names, overwrite: false)
            throw error
        }
    }

    private func recipeRegisteringJustInTime(for type: Any.Type, key: ObjectIdentifier) -> GraphRecipe? {
        lock.lock()
        if let (_, recipe) = findRecipeUpwards(for: key) {
            lock.unlock()
            return recipe
        }
        lock.unlock()
        guard let injectable = type as? any Injectable.Type else { return nil }
        injectable.register(in: self)
        lock.lock()
        defer { lock.unlock() }
        return findRecipeUpwards(for: key)?.1
    }

    private func recordFailure(_ chain: [String], overwrite: Bool) {
        lock.lock()
        defer { lock.unlock() }
        let root = rootContainer
        if overwrite || root.lastFailurePath.isEmpty {
            root.lastFailurePath = chain
        }
    }

    // MARK: - Precondiciones por adelantado

    /// Evalúa todas las `@Precondition` alcanzables desde `type` ANTES de construir cualquier nodo,
    /// sin importar el orden de los parámetros. Los subárboles `@Scoped` ya instanciados se omiten
    /// (sus precondiciones se cumplieron al crearlos). Los valores quedan en el contexto y se reutilizan.
    private func evaluatePreconditionsUpFront<T>(for type: T.Type, context: ResolutionContext) throws {
        let key = ObjectIdentifier(type)
        lock.lock()
        validateCaches()
        let known = subgraphHasPreconditions[key]
        lock.unlock()
        if known == false { return }

        var visited = Set<ObjectIdentifier>()
        var found: [Any.Type] = []
        var skippedInstantiated = false
        collectPreconditionTypes(type, visited: &visited, into: &found, skippedInstantiated: &skippedInstantiated)

        if !found.isEmpty || !skippedInstantiated {
            lock.lock()
            subgraphHasPreconditions[key] = !found.isEmpty
            lock.unlock()
        }
        for precondition in found {
            try resolveOpened(precondition, context: context)
        }
    }

    private func resolveOpened<P>(_ type: P.Type, context: ResolutionContext) throws {
        _ = try resolve(type, context: context)
    }

    private func collectPreconditionTypes(
        _ currentType: Any.Type,
        visited: inout Set<ObjectIdentifier>,
        into found: inout [Any.Type],
        skippedInstantiated: inout Bool
    ) {
        let key = ObjectIdentifier(currentType)
        guard visited.insert(key).inserted else { return }
        guard let recipe = recipeRegisteringJustInTime(for: currentType, key: key) else { return }

        switch recipe.lifetime {
        case .precondition:
            found.append(currentType)
            return
        case .scoped(let scope):
            lock.lock()
            let alreadyBuilt = findBoxUpwards(matching: scope)?.instances[key] != nil
            lock.unlock()
            if alreadyBuilt {
                skippedInstantiated = true
                return
            }
        case .transient, .businessRule:
            break
        }
        for dependency in recipe.dependencyTypes {
            collectPreconditionTypes(dependency, visited: &visited, into: &found, skippedInstantiated: &skippedInstantiated)
        }
    }

    /// Construye cualquier clase o struct al vuelo pasando su `.init` directamente,
    /// resolviendo todos sus parámetros del contenedor actual sin necesidad de haberlo registrado antes.
    public func build<T, each D>(
        _ initializer: @escaping (repeat each D) throws -> T
    ) throws -> T {
        if let context = ResolutionContext.active {
            return try initializer(repeat try self.resolve((each D).self, context: context))
        }
        return try ResolutionContext.run { context in
            try initializer(repeat try self.resolve((each D).self, context: context))
        }
    }

    /// Verifica cuántos objetos están actualmente instanciados en esta caja específica del Scope.
    public var activeInstanceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return instances.count
    }

    /// Devuelve el rastro exacto de tipos recorridos en la última resolución fallida.
    public var lastFailureTrace: [String] {
        lock.lock()
        defer { lock.unlock() }
        return rootContainer.lastFailurePath
    }

    /// Genera un snapshot jerárquico completo (serializable a JSON) de este contenedor y sus sub-scopes.
    public func snapshot() -> GraphScopeSnapshot {
        lock.lock()
        defer { lock.unlock() }

        let nodeSnapshots: [GraphNodeSnapshot] = recipes.map { key, recipe in
            let kindLabel: String
            let ownerScopeLabel: String
            let instantiated: Bool

            switch recipe.lifetime {
            case .transient:
                kindLabel = "@Provider"
                ownerScopeLabel = self.scopeID.name
                instantiated = false
            case .businessRule:
                kindLabel = "@BusinessRule"
                ownerScopeLabel = self.scopeID.name
                instantiated = false
            case .precondition(let s):
                kindLabel = "@Precondition"
                ownerScopeLabel = s.name
                instantiated = false
            case .scoped(let s):
                kindLabel = (s == GlobalScope.scopeID) ? "@Singleton" : "@Scoped"
                ownerScopeLabel = s.name
                let box = findBoxUpwards(matching: s) ?? self
                instantiated = box.instances[key] != nil
            }

            return GraphNodeSnapshot(
                type: recipe.typeName,
                kind: kindLabel,
                ownerScope: ownerScopeLabel,
                isInstantiated: instantiated,
                dependencies: recipe.dependencies
            )
        }.sorted { $0.type < $1.type }

        let childSnapshots = children.compactMap { $0.value?.snapshot() }

        return GraphScopeSnapshot(
            scope: scopeID.name,
            isTornDown: isTornDown,
            activeInstanceCount: instances.count,
            nodes: nodeSnapshots,
            children: childSnapshots
        )
    }

    /// Verifica si un tipo específico ya fue instanciado en esta caja (útil para probar inicialización Lazy).
    public func isInstantiated<T>(_ type: T.Type) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return instances[ObjectIdentifier(type)] != nil
    }

    /// Verifica si existe una receta registrada para `T` en este Scope o en cualquiera de sus padres.
    public func hasRecipe<T>(for type: T.Type) -> Bool {
        if type == ScopeContainer.self { return true }
        lock.lock()
        defer { lock.unlock() }
        return findRecipeUpwards(for: ObjectIdentifier(type)) != nil
    }

    /// Inspecciona el sub-grafo de recetas de `type` (sin instanciar ningún objeto)
    /// y devuelve todas las `@Precondition` de las que depende directa o indirectamente.
    public func preconditionsInSubgraph<T>(for type: T.Type) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        var visited = Set<ObjectIdentifier>()
        var result: [String] = []
        collectPreconditions(forAny: type, visited: &visited, into: &result)
        return result
    }

    /// Inspecciona el sub-grafo de recetas de `type` (sin instanciar ningún objeto)
    /// y devuelve todas las `@BusinessRule` de las que depende directa o indirectamente.
    public func businessRulesInSubgraph<T>(for type: T.Type) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        var visited = Set<ObjectIdentifier>()
        var result: [String] = []
        collectBusinessRules(forAny: type, visited: &visited, into: &result)
        return result
    }

    // MARK: - Destrucción de Scope y Auditoría de Memory Leaks

    /// Cierra este Scope y todos sus Scopes hijos en cascada, liberando todas sus instancias de RAM.
    /// - Returns: Lista de nombres de clases que permanecieron en memoria después de vaciar el Scope
    ///   (si es vacío `[]`, el contador de referencias ARC llegó a 0 limpiamente para todos los objetos).
    @discardableResult
    public func teardown() -> [String] {
        lock.lock()
        guard !isTornDown else {
            lock.unlock()
            return []
        }
        isTornDown = true

        let liveChildren = children.compactMap(\.value)
        children.removeAll()
        // Soltar las referencias fuertes del diccionario de este Scope (se conservan localmente
        // para notificar a ScopeDisposable fuera del lock) e invalidar cachés del árbol.
        var released = Array(instances.values)
        instances.removeAll()
        cachedRecipes.removeAll(keepingCapacity: true)
        cachedScopeBoxes.removeAll(keepingCapacity: true)
        let tracked = leakTracker
        leakTracker.removeAll()
        rootContainer.generation &+= 1
        lock.unlock()

        var leakedTypes: [String] = []

        // 1. Destruir primero todos los Scopes hijos hacia abajo en cascada
        for child in liveChildren {
            leakedTypes.append(contentsOf: child.teardown())
        }

        // 2. Notificar a las instancias que implementen ScopeDisposable (código de usuario: sin lock)
        for instance in released {
            if let disposable = instance as? ScopeDisposable {
                disposable.onScopeTeardown()
            }
        }
        released.removeAll()

        // 3. Auditar vía WeakObjectBox si algún objeto quedó retenido por un retain cycle
        for box in tracked where box.object != nil {
            leakedTypes.append(box.typeName)
        }
        return leakedTypes
    }

    // MARK: - Helpers Privados

    private var rootContainer: ScopeContainer {
        rootRef ?? self
    }

    /// Vacía las cachés de esta caja si algún registro en el árbol las dejó obsoletas.
    private func validateCaches() {
        let current = rootContainer.generation
        if cacheGeneration != current {
            cachedRecipes.removeAll(keepingCapacity: true)
            cachedScopeBoxes.removeAll(keepingCapacity: true)
            subgraphHasPreconditions.removeAll(keepingCapacity: true)
            cacheGeneration = current
        }
    }

    private func findBoxUpwards(matching targetScopeID: ScopeID) -> ScopeContainer? {
        validateCaches()
        if let cached = cachedScopeBoxes[targetScopeID] {
            return cached
        }
        if self.scopeID == targetScopeID || self.compatibleScopeIDs.contains(targetScopeID) {
            cachedScopeBoxes[targetScopeID] = self
            return self
        }
        if let fromParent = parent?.findBoxUpwards(matching: targetScopeID) {
            cachedScopeBoxes[targetScopeID] = fromParent
            return fromParent
        }
        return nil
    }

    private func findRecipeUpwards(for key: ObjectIdentifier) -> (ScopeContainer, GraphRecipe)? {
        validateCaches()
        if let cached = cachedRecipes[key] {
            return cached
        }
        if let recipe = recipes[key] {
            let found = (self, recipe)
            cachedRecipes[key] = found
            return found
        }
        if let fromParent = parent?.findRecipeUpwards(for: key) {
            cachedRecipes[key] = fromParent
            return fromParent
        }
        return nil
    }

    private func collectPreconditions(
        forAny currentType: Any.Type,
        visited: inout Set<ObjectIdentifier>,
        into result: inout [String]
    ) {
        let key = ObjectIdentifier(currentType)
        guard !visited.contains(key) else { return }
        visited.insert(key)

        if findRecipeUpwards(for: key) == nil, let injectable = currentType as? any Injectable.Type {
            injectable.register(in: self)
        }

        guard let (_, recipe) = findRecipeUpwards(for: key) else {
            if currentType is any Precondition.Type {
                let name = String(reflecting: currentType)
                if !result.contains(name) { result.append(name) }
            }
            return
        }

        if case .precondition = recipe.lifetime {
            if !result.contains(recipe.typeName) {
                result.append(recipe.typeName)
            }
        } else if currentType is any Precondition.Type {
            if !result.contains(recipe.typeName) {
                result.append(recipe.typeName)
            }
        }

        for depType in recipe.dependencyTypes {
            collectPreconditions(forAny: depType, visited: &visited, into: &result)
        }
    }

    private func collectBusinessRules(
        forAny currentType: Any.Type,
        visited: inout Set<ObjectIdentifier>,
        into result: inout [String]
    ) {
        let key = ObjectIdentifier(currentType)
        guard !visited.contains(key) else { return }
        visited.insert(key)

        if findRecipeUpwards(for: key) == nil, let injectable = currentType as? any Injectable.Type {
            injectable.register(in: self)
        }

        guard let (_, recipe) = findRecipeUpwards(for: key) else { return }

        if case .businessRule = recipe.lifetime {
            if !result.contains(recipe.typeName) {
                result.append(recipe.typeName)
            }
        }

        for depType in recipe.dependencyTypes {
            collectBusinessRules(forAny: depType, visited: &visited, into: &result)
        }
    }

    private func registerRecipe<T, each D>(
        for type: T.Type,
        lifetime: NodeLifetime,
        factory: @escaping (repeat each D) throws -> T
    ) {
        lock.lock()
        defer { lock.unlock() }

        let key = ObjectIdentifier(type)
        let typeName = String(reflecting: type)
        var depNames: [String] = []
        var depTypes: [Any.Type] = []
        repeat depNames.append(String(reflecting: (each D).self))
        repeat depTypes.append((each D).self)

        let recipe = GraphRecipe(
            typeName: typeName,
            lifetime: lifetime,
            dependencies: depNames,
            dependencyTypes: depTypes,
            build: { resolver in
                try factory(repeat try resolver.resolve((each D).self))
            }
        )
        recipes[key] = recipe
        if lifetime == .singleton && self !== rootContainer && rootContainer.recipes[key] == nil {
            rootContainer.recipes[key] = recipe
        }
        rootContainer.generation &+= 1
    }

    private func trackForLeaksIfNeeded(_ instance: Any, typeName: String) {
        guard auditLeaks else { return }
        if type(of: instance) is AnyClass {
            let object = instance as AnyObject
            leakTracker.append(WeakObjectBox(typeName: typeName, object: object))
        }
    }
}

// MARK: - Contexto de resolución y construcciones en curso

/// Estado de UNA resolución de primer nivel (pila para ciclos, precondiciones ya evaluadas).
/// Viaja en un `@TaskLocal` para que las llamadas anidadas a `resolve` desde factories lo compartan;
/// se ignora si se lee desde otro hilo (p. ej. un `Task {}` lanzado dentro de una factory).
final class ResolutionContext: @unchecked Sendable {
    @TaskLocal private static var current: ResolutionContext?

    private let thread = ObjectIdentifier(Thread.current)
    private(set) var stack: [ObjectIdentifier] = []
    private(set) var names: [String] = []
    var preconditionValues: [ObjectIdentifier: Any] = [:]
    /// Construcción ajena que este contexto está esperando (protegido por `PendingBuild.condition`).
    var waitingFor: PendingBuild?

    static var active: ResolutionContext? {
        guard let context = current, context.thread == ObjectIdentifier(Thread.current) else { return nil }
        return context
    }

    static func run<R>(_ body: (ResolutionContext) throws -> R) throws -> R {
        let context = ResolutionContext()
        return try $current.withValue(context) { try body(context) }
    }

    func push(_ key: ObjectIdentifier, name: String) {
        stack.append(key)
        names.append(name)
    }

    func pop() {
        stack.removeLast()
        names.removeLast()
    }
}

/// Construcción `@Scoped`/`@Singleton` en curso. Otros hilos esperan en lugar de construir dos veces.
final class PendingBuild: @unchecked Sendable {
    private static let condition = NSCondition()

    let owner: ResolutionContext
    private var done = false

    init(owner: ResolutionContext) {
        self.owner = owner
    }

    func finish() {
        Self.condition.lock()
        done = true
        Self.condition.broadcast()
        Self.condition.unlock()
    }

    /// Espera a que la construcción termine. Devuelve `false` (sin esperar) si el dueño, directa o
    /// transitivamente, está esperando a `waiter`: eso sería un ciclo entre hilos (deadlock).
    func wait(by waiter: ResolutionContext) -> Bool {
        Self.condition.lock()
        defer { Self.condition.unlock() }
        if done { return true }
        var current: ResolutionContext? = owner
        var hops = 0
        while let context = current, hops < 1_000 {
            if context === waiter { return false }
            current = context.waitingFor?.owner
            hops += 1
        }
        waiter.waitingFor = self
        while !done {
            Self.condition.wait()
        }
        waiter.waitingFor = nil
        return true
    }
}

// MARK: - Aislamiento @MainActor

public extension ScopeContainer {
    /// Usado por la expansión de `@Inject` en tipos `@MainActor`: construye en el hilo principal
    /// o lanza `GraphError.mainActorRequired` (antes: crash de `MainActor.assumeIsolated`).
    static func onMainActor<T: Sendable>(_ body: @MainActor () throws -> T) throws -> T {
        guard Thread.isMainThread else {
            throw reportProgrammerError(.mainActorRequired(type: String(reflecting: T.self)))
        }
        return try MainActor.assumeIsolated(body)
    }

    /// Resuelve `T` saltando al `MainActor` (para ViewModels `@MainActor @Inject` pedidos desde background).
    func resolveOnMainActor<T: Sendable>(_ type: T.Type = T.self) async throws -> T {
        try await MainActor.run { try self.resolve(type) }
    }
}

// MARK: - Red de seguridad para errores de programación

public extension ScopeContainer {
    /// Política ante errores de programación detectados en runtime (ver `ProgrammerErrorPolicy`).
    /// Por defecto: `.assertInDebug`, salvo dentro de un runner de tests (`.throwOnly`).
    static var programmerErrorPolicy: ProgrammerErrorPolicy {
        get { ProgrammerErrorPolicyStore.shared.value }
        set { ProgrammerErrorPolicyStore.shared.value = newValue }
    }

    /// Aplica la política y devuelve el error para lanzarlo.
    static func reportProgrammerError(_ error: GraphError) -> GraphError {
        guard error.isProgrammerError else { return error }
        switch programmerErrorPolicy {
        case .throwOnly:
            break
        case .assertInDebug:
            assertionFailure("DaggerSwift: \(error.description). Debió detectarse al compilar (dagger-graph).")
        case .trap:
            fatalError("DaggerSwift: \(error.description). Debió detectarse al compilar (dagger-graph).")
        }
        return error
    }
}

final class ProgrammerErrorPolicyStore: @unchecked Sendable {
    static let shared = ProgrammerErrorPolicyStore()
    private let lock = NSLock()
    private var stored: ProgrammerErrorPolicy?

    var value: ProgrammerErrorPolicy {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stored ?? (Self.isRunningTests ? .throwOnly : .assertInDebug)
        }
        set {
            lock.lock()
            stored = newValue
            lock.unlock()
        }
    }

    /// Heurística: `swift test` (swiftpm-testing-helper / xctest) o Xcode (XCTestConfigurationFilePath).
    static let isRunningTests: Bool = {
        let info = ProcessInfo.processInfo
        let env = info.environment
        return ["swiftpm-testing-helper", "xctest"].contains(info.processName)
            || env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
    }()
}
