// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import Foundation

/// Grafo generado para la raíz [NestedAppModule]: factories directas, sin `resolve`.
final class DaggerGraph_NestedAppModule: @unchecked Sendable {
    let lock = NSRecursiveLock()
    init() {}

    /// Abre el scope `NestedSessionScope` (sus `@Scoped` viven mientras viva el objeto devuelto).
    func makeNestedSessionScope() -> NestedSessionScopeGraph { NestedSessionScopeGraph(parent: self) }

    private var _nestedApiClient: NestedApiClient?
    func nestedApiClient() -> NestedApiClient {
        lock.lock(); defer { lock.unlock() }
        if let cached = _nestedApiClient { return cached }
        let value = NestedAppModule.api()
        _nestedApiClient = value
        return value
    }

    func nestedSession() throws -> NestedSession {
        guard let value = NestedAppModule.session() else {
            throw GraphError.unmetPrecondition(type: String(reflecting: NestedSession.self), reason: "Se requiere sesión")
        }
        return value
    }

    func nestedSessionGate() throws -> NestedSessionGate {
        try _pre_nestedSessionGate()
        return try NestedSessionGate(session: nestedSession())
    }

    func _pre_nestedSessionGate() throws {
        _ = try nestedSession()
    }
}
