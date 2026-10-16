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
    static func register(in container: ScopeContainer)
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
    let build: (ScopeContainer) throws -> Any
}

/// Motor del Grafo y Contenedor Jerárquico de Scopes (`Global` -> `Session` -> `Module`).
/// Thread-safe (`Sendable`) mediante `NSRecursiveLock` compartido por árbol:
/// puede invocarse desde `@MainActor` (SwiftUI / UIKit) o desde hilos de background, `Actor`s y CLIs.
public final class ScopeContainer: @unchecked Sendable {
    /// Identificador del Scope que representa esta caja (ej. `GlobalScope`, `ValidatedSession`, `LoansModule`).
    public let scopeID: ScopeID

    /// Referencia fuerte al contenedor padre (más longevo). `nil` únicamente en `GlobalScope`.
    public let parent: ScopeContainer?

    /// Lock recursivo compartido desde la raíz del árbol para garantizar thread-safety sin deadlocks.
    private let lock: NSRecursiveLock

    /// Contenedores hijos activos (referencia `weak` para que mueran solos cuando su pantalla se cierra).
    private var children: [WeakScopeContainer] = []

    /// Recetas registradas en este nivel del grafo (Costo cero al arrancar: son closures, no instancias).
    private var recipes: [ObjectIdentifier: GraphRecipe] = [:]

    /// Instancias vivas cuyo ciclo de vida pertenece exactamente a ESTE `scopeID`.
    private var instances: [ObjectIdentifier: Any] = [:]

    /// Rastreador de objetos creados en este Scope para detectar retain cycles al cerrar el Scope.
    private var leakTracker: [WeakObjectBox] = []

    /// Pila compartida en la raíz para detectar ciclos de dependencias (`A -> B -> A`).
    private var resolutionStack: [ObjectIdentifier] = []
    private var resolutionNames: [String] = []

    /// Indica si este contenedor ya fue cerrado mediante `teardown()`.
    public private(set) var isTornDown: Bool = false

    public init(scopeID: ScopeID = GlobalScope.scopeID, parent: ScopeContainer? = nil) {
        self.scopeID = scopeID
        self.parent = parent
        self.lock = parent?.lock ?? NSRecursiveLock()
    }

    /// Crea un contenedor raíz (`GlobalScope`) opcionalmente cargando una lista de módulos base.
    public static func root(modules: [any GraphModule.Type] = []) -> ScopeContainer {
        let container = ScopeContainer(scopeID: GlobalScope.scopeID, parent: nil)
        for module in modules {
            module.register(in: container)
        }
        return container
    }

    // MARK: - Jerarquía de Scopes (Hijos) y Vínculo con UIKit / Coordinators

    /// Crea un contenedor hijo atado al Scope de un módulo o precondición.
    /// Si el tipo conforma `GraphModule`, registra automáticamente sus recetas locales.
    @discardableResult
    public func makeChildScope<S: GraphScope>(
        for scope: S.Type,
        modules: [any GraphModule.Type] = []
    ) -> ScopeContainer {
        lock.lock()
        defer { lock.unlock() }

        let child = ScopeContainer(scopeID: S.scopeID, parent: self)
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
        #if canImport(ObjectiveC)
        let key = Unmanaged.passUnretained(self).toOpaque()
        objc_setAssociatedObject(owner, key, token, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        #endif
        return token
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
        recipes[key] = GraphRecipe(
            typeName: typeName,
            lifetime: .precondition(P.scopeID),
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
    /// 1. Verifica que no existan ciclos (`A -> B -> A`).
    /// 2. Busca la receta en el Scope actual o subiendo hacia los padres (`parent`).
    /// 3. Si es `@Scoped` o `@Singleton`, sube hasta la caja dueña (`findBoxUpwards`) y resuelve desde ella.
    public func resolve<T>(_ type: T.Type = T.self) throws -> T {
        if type == ScopeContainer.self, let selfT = self as? T {
            return selfT
        }

        lock.lock()
        defer { lock.unlock() }

        let key = ObjectIdentifier(type)
        let typeName = String(reflecting: type)
        let rootBox = self.rootContainer

        // 1. Detección de ciclos en el grafo
        if rootBox.resolutionStack.contains(key) {
            let cycleChain = rootBox.resolutionNames + [typeName]
            throw GraphError.circularDependency(chain: cycleChain)
        }

        // 2. Buscar qué contenedor tiene registrada la receta (este o algún ancestro).
        //    Si no existe pero el tipo es @Inject (Injectable), se auto-registra Just-In-Time.
        if findRecipeUpwards(for: key) == nil, let injectable = type as? any Injectable.Type {
            injectable.register(in: self)
        }
        guard let (_, recipe) = findRecipeUpwards(for: key) else {
            throw GraphError.unregisteredDependency(type: typeName, searchedFromScope: self.scopeID)
        }

        // 3. Ejecutar según el ciclo de vida del nodo
        switch recipe.lifetime {
        case .transient, .businessRule, .precondition:
            return try executeWithCycleTracking(key: key, name: typeName, root: rootBox) {
                guard let instance = try recipe.build(self) as? T else {
                    throw GraphError.unregisteredDependency(type: typeName, searchedFromScope: self.scopeID)
                }
                return instance
            }

        case .scoped(let targetScopeID):
            // Subir desde el contenedor actual para encontrar la caja dueña del Scope
            guard let ownerBox = findBoxUpwards(matching: targetScopeID), !ownerBox.isTornDown else {
                throw GraphError.scopeNotActive(
                    requestedScope: targetScopeID,
                    currentScope: self.scopeID,
                    dependencyType: typeName
                )
            }

            // Si ya existe en la caja dueña, devolverla en O(1)
            if let cached = ownerBox.instances[key] as? T {
                return cached
            }

            // Construimos usando 'ownerBox' como resolver para garantizar la Regla de Oro:
            // un Scope padre (ej. Global) NO puede depender de cosas registradas solo en un Scope hijo (ej. Loans).
            return try executeWithCycleTracking(key: key, name: typeName, root: rootBox) {
                guard let newInstance = try recipe.build(ownerBox) as? T else {
                    throw GraphError.unregisteredDependency(type: typeName, searchedFromScope: ownerBox.scopeID)
                }
                ownerBox.instances[key] = newInstance
                ownerBox.trackForLeaksIfNeeded(newInstance, typeName: typeName)
                return newInstance
            }
        }
    }

    /// Construye cualquier clase o struct al vuelo pasando su `.init` directamente,
    /// resolviendo todos sus parámetros del contenedor actual sin necesidad de haberlo registrado antes.
    public func build<T, each D>(
        _ initializer: @escaping (repeat each D) throws -> T
    ) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try initializer(repeat try self.resolve((each D).self))
    }

    /// Verifica cuántos objetos están actualmente instanciados en esta caja específica del Scope.
    public var activeInstanceCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return instances.count
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

    // MARK: - Destrucción de Scope y Auditoría de Memory Leaks

    /// Cierra este Scope y todos sus Scopes hijos en cascada, liberando todas sus instancias de RAM.
    /// - Returns: Lista de nombres de clases que permanecieron en memoria después de vaciar el Scope
    ///   (si es vacío `[]`, el contador de referencias ARC llegó a 0 limpiamente para todos los objetos).
    @discardableResult
    public func teardown() -> [String] {
        lock.lock()
        defer { lock.unlock() }

        guard !isTornDown else { return [] }
        isTornDown = true

        var leakedTypes: [String] = []

        // 1. Destruir primero todos los Scopes hijos hacia abajo en cascada
        for childRef in children {
            if let child = childRef.value {
                leakedTypes.append(contentsOf: child.teardown())
            }
        }
        children.removeAll()

        // 2. Notificar a las instancias que implementen ScopeDisposable para cancelar Tasks/Timers
        for instance in instances.values {
            if let disposable = instance as? ScopeDisposable {
                disposable.onScopeTeardown()
            }
        }

        // 3. Soltar todas las referencias fuertes del diccionario de este Scope
        instances.removeAll()

        // 4. Auditar inmediatamente vía WeakObjectBox si algún objeto quedó retenido por un retain cycle
        for box in leakTracker where box.object != nil {
            leakedTypes.append(box.typeName)
        }
        leakTracker.removeAll()

        return leakedTypes
    }

    // MARK: - Helpers Privados

    private var rootContainer: ScopeContainer {
        var current = self
        while let next = current.parent {
            current = next
        }
        return current
    }

    private func findBoxUpwards(matching targetScopeID: ScopeID) -> ScopeContainer? {
        if self.scopeID == targetScopeID {
            return self
        }
        return parent?.findBoxUpwards(matching: targetScopeID)
    }

    private func findRecipeUpwards(for key: ObjectIdentifier) -> (ScopeContainer, GraphRecipe)? {
        if let recipe = recipes[key] {
            return (self, recipe)
        }
        return parent?.findRecipeUpwards(for: key)
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
        recipes[key] = GraphRecipe(
            typeName: typeName,
            lifetime: lifetime,
            build: { resolver in
                try factory(repeat try resolver.resolve((each D).self))
            }
        )
    }

    private func executeWithCycleTracking<R>(
        key: ObjectIdentifier,
        name: String,
        root: ScopeContainer,
        operation: () throws -> R
    ) rethrows -> R {
        root.resolutionStack.append(key)
        root.resolutionNames.append(name)
        defer {
            root.resolutionStack.removeLast()
            root.resolutionNames.removeLast()
        }
        return try operation()
    }

    private func trackForLeaksIfNeeded(_ instance: Any, typeName: String) {
        let mirror = Mirror(reflecting: instance)
        if mirror.displayStyle == .class {
            let object = instance as AnyObject
            leakTracker.append(WeakObjectBox(typeName: typeName, object: object))
        }
    }
}
