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
    /// Se intentó guardar o resolver una dependencia cuyo Scope dueño no está activo en la jerarquía hacia arriba.
    case scopeNotActive(requestedScope: ScopeID, currentScope: ScopeID, dependencyType: String)
    /// Se detectó un ciclo infinito en el grafo (`A -> B -> A`).
    case circularDependency(chain: [String])

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
        }
    }
}
