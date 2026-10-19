//
//  GraphScope.swift
//  DaggerSwift
//
//  Created by Saldivar on 16/10/26.
//

import Foundation

/// Identificador único en tiempo de compilación para un Scope dentro del árbol del grafo.
/// Usa `ObjectIdentifier` (puntero de metadatos del tipo, O(1)) para evitar colisiones de Strings.
public struct ScopeID: Hashable, Sendable, CustomStringConvertible {
    public let id: ObjectIdentifier
    public let name: String

    public init<T>(_ type: T.Type) {
        self.id = ObjectIdentifier(type)
        self.name = String(reflecting: type)
    }

    public var description: String { name }

    public static func == (lhs: ScopeID, rhs: ScopeID) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Protocolo base para cualquier entidad que defina un tiempo de vida (Scope) en el grafo.
/// Todo `@Module` (`Modulable`) y toda `@Precondition` conforman automáticamente `GraphScope`,
/// eliminando la necesidad de declarar llaves o `CodingKeys` manuales.
public protocol GraphScope {
    nonisolated static var scopeID: ScopeID { get }
}

public extension GraphScope {
    nonisolated static var scopeID: ScopeID {
        ScopeID(Self.self)
    }
}

/// Scope raíz que vive durante toda la ejecución de la aplicación (equivalente a `@Singleton`).
public enum GlobalScope: GraphScope {}

/// Protocolo para dependencias de Precondición de Estado/Negocio (ej. `ValidatedSession`).
/// - Si un componente depende de una `Precondition` y ésta no se cumple (ej. Deep Link con la app cerrada),
///   el motor del grafo detiene la resolución antes de instanciar el componente e informa qué precondición falta.
/// - Además, toda `Precondition` es un `GraphScope`: puedes atar dependencias a `@Scoped(ValidatedSession.self)`
///   y morirán automáticamente cuando la sesión se cierre.
public protocol Precondition: GraphScope {}

/// Protocolo opcional para dependencias que necesitan cancelar tareas asíncronas, timers o streams
/// en el instante exacto en que su Scope se cierra (antes de que ARC libere la instancia).
public protocol ScopeDisposable: AnyObject {
    func onScopeTeardown()
}

/// Ciclo de vida de un nodo dentro del grafo.
public enum NodeLifetime: Sendable, Equatable {
    /// Nueva instancia en cada resolución (`@Provider`). No se almacena en ningún contenedor.
    case transient
    /// Regla de negocio / Feature Flag que evalúa dinámicamente qué variante o implementación entregar.
    case businessRule
    /// Precondición que debe cumplirse antes de construir el sub-árbol que depende de ella.
    case precondition(ScopeID)
    /// Instancia única almacenada dentro de la caja dueña del `ScopeID` indicado (`@Singleton` o `@Scoped`).
    case scoped(ScopeID)

    public static var singleton: NodeLifetime {
        .scoped(GlobalScope.scopeID)
    }
}

/// Errores tipados emitidos por el motor de resolución del grafo.
/// Permiten que el Coordinator (separado de DaggerSwift) reaccione cuando falta una precondición como `Sesión`.
public enum GraphError: Error, Equatable, CustomStringConvertible, Sendable {
    /// El componente requiere una precondición (ej. `ValidatedSession`) que aún no se ha cumplido.
    case unmetPrecondition(type: String, reason: String)
    /// Se intentó resolver un tipo para el cual no existe receta ni en el Scope actual ni en sus padres.
    case unregisteredDependency(type: String, searchedFromScope: ScopeID)
    /// Se intentó resolver una dependencia cuyo Scope dueño NUNCA se abrió en la jerarquía hacia arriba
    /// (falta `makeChildScope(for:)`). Error de programación: dagger-graph lo detecta al compilar.
    case scopeNotActive(requestedScope: ScopeID, currentScope: ScopeID, dependencyType: String)
    /// El Scope dueño existió pero ya se cerró (`teardown()`): alguien retuvo una referencia a un flujo
    /// terminado. Error de estado: lo maneja el Coordinator (p. ej. volver a abrir el flujo).
    case scopeClosed(scope: ScopeID, dependencyType: String)
    /// Se detectó un ciclo infinito en el grafo (`A -> B -> A`).
    case circularDependency(chain: [String])
    /// Un tipo `@MainActor` se intentó construir fuera del hilo principal.
    /// Resuélvelo desde `@MainActor` o con `try await container.resolveOnMainActor(T.self)`.
    case mainActorRequired(type: String)

    public var description: String {
        switch self {
        case let .unmetPrecondition(type, reason):
            return "Precondición no cumplida [\(type)]: \(reason)"
        case let .unregisteredDependency(type, scope):
            return "Dependencia no registrada [\(type)] buscando desde el scope [\(scope)]"
        case let .scopeNotActive(requested, current, dep):
            return "El scope [\(requested)] requerido por [\(dep)] no está activo en la cadena de padres de [\(current)]"
        case let .circularDependency(chain):
            return "Ciclo de dependencias detectado: " + chain.joined(separator: " -> ")
        case let .scopeClosed(scope, dep):
            return "El scope [\(scope)] de [\(dep)] ya se cerró (teardown); vuelve a abrir el flujo"
        case let .mainActorRequired(type):
            return "[\(type)] es @MainActor y se intentó construir fuera del hilo principal; usa resolveOnMainActor(_:)"
        }
    }
}

// MARK: - Errores de programación vs. errores de estado

public extension GraphError {
    /// `true` si el error es un bug del código que debió detectarse al compilar (dagger-graph):
    /// ciclo, dependencia no registrada, scope nunca abierto, tipo `@MainActor` pedido fuera del hilo principal.
    /// `false` si depende del estado de la app (`unmetPrecondition`, `scopeClosed`): el Coordinator lo
    /// convierte en navegación (login, reabrir el flujo, guardar el deep link).
    var isProgrammerError: Bool {
        switch self {
        case .unmetPrecondition, .scopeClosed:
            return false
        case .unregisteredDependency, .scopeNotActive, .circularDependency, .mainActorRequired:
            return true
        }
    }
}

/// Qué hacer cuando el runtime encuentra un error de programación (la red de seguridad si el CLI no corrió).
public enum ProgrammerErrorPolicy: Sendable, Equatable {
    /// `assertionFailure` en builds DEBUG de DaggerSwift (truena al desarrollar) y en release solo lanza.
    /// Ojo: con el XCFramework de release (compilado sin DEBUG) equivale a `.throwOnly`; usa `.trap` si
    /// quieres que truene también ahí durante el desarrollo.
    case assertInDebug
    /// `fatalError` siempre: útil en el target de desarrollo de la app.
    case trap
    /// Solo lanza el error (por defecto dentro de tests, que provocan estos errores a propósito).
    case throwOnly
}
