// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import Foundation

/// Grafo generado para la raíz [BenchModuleV0_1, BenchModuleV1]: factories directas, sin `resolve`.
final class DaggerGraph_BenchModuleV1: @unchecked Sendable {
    let lock = NSRecursiveLock()
    init() {}

    /// Abre el scope `BenchFeatureScope` (sus `@Scoped` viven mientras viva el objeto devuelto).
    func makeBenchFeatureScope() -> BenchFeatureScopeGraph { BenchFeatureScopeGraph(parent: self) }

    private var _benchApiClientProtocol: (any BenchApiClientProtocol)?
    func benchApiClientProtocol() throws -> any BenchApiClientProtocol {
        lock.lock(); defer { lock.unlock() }
        if let cached = _benchApiClientProtocol { return cached }
        let value = BenchModuleV0_1.apiClient()
        _benchApiClientProtocol = value
        return value
    }

    func benchRepositoryImpl() throws -> BenchRepositoryImpl {
        try BenchRepositoryImpl(api: benchApiClientProtocol())
    }
}
