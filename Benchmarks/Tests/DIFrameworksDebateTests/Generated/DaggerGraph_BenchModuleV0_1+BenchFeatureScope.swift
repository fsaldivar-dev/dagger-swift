// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import Foundation

extension DaggerGraph_BenchModuleV0_1 {
    /// Scope `BenchFeatureScope` del grafo [BenchModuleV0_1].
    final class BenchFeatureScopeGraph: @unchecked Sendable {
        let parent: DaggerGraph_BenchModuleV0_1
        init(parent: DaggerGraph_BenchModuleV0_1) { self.parent = parent }
        var lock: NSRecursiveLock { parent.lock }

        private var _benchRepositoryProtocol: (any BenchRepositoryProtocol)?
        func benchRepositoryProtocol() -> any BenchRepositoryProtocol {
            lock.lock(); defer { lock.unlock() }
            if let cached = _benchRepositoryProtocol { return cached }
            let value = BenchModuleV0_1.repository()
            _benchRepositoryProtocol = value
            return value
        }

        func benchUseCase() -> BenchUseCase {
            BenchUseCase(repository: benchRepositoryProtocol())
        }
    }
}
