// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import Foundation

/// Grafo generado para la raíz [BenchModuleV0_1, BenchModuleV1, BenchModuleV2]: factories directas, sin `resolve`.
final class DaggerGraph_BenchModuleV2: @unchecked Sendable {
    let lock = NSRecursiveLock()
    init() {}

    /// Abre el scope `BenchFeatureScope` (sus `@Scoped` viven mientras viva el objeto devuelto).
    func makeBenchFeatureScope() -> BenchFeatureScopeGraph { BenchFeatureScopeGraph(parent: self) }

    private var _benchApiClientProtocol: (any BenchApiClientProtocol)?
    func benchApiClientProtocol() -> any BenchApiClientProtocol {
        lock.lock(); defer { lock.unlock() }
        if let cached = _benchApiClientProtocol { return cached }
        let value = BenchModuleV0_1.apiClient()
        _benchApiClientProtocol = value
        return value
    }

    func benchRepositoryImpl() -> BenchRepositoryImpl {
        BenchRepositoryImpl(api: benchApiClientProtocol())
    }

    func benchSessionPrecondition() throws -> BenchSessionPrecondition {
        guard let value = BenchModuleV2.validateSession() else {
            throw GraphError.unmetPrecondition(type: String(reflecting: BenchSessionPrecondition.self), reason: "Sesión activa requerida antes de instanciar BenchProtectedInteractor")
        }
        return value
    }
}
