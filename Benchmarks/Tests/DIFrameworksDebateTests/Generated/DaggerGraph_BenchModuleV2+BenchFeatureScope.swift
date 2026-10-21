// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import Foundation

extension DaggerGraph_BenchModuleV2 {
    /// Scope `BenchFeatureScope` del grafo [BenchModuleV0_1, BenchModuleV1, BenchModuleV2].
    final class BenchFeatureScopeGraph: @unchecked Sendable {
        let parent: DaggerGraph_BenchModuleV2
        init(parent: DaggerGraph_BenchModuleV2) { self.parent = parent }
        var lock: NSRecursiveLock { parent.lock }

        private var _benchProtectedInteractor: BenchProtectedInteractor?
        func benchProtectedInteractor() throws -> BenchProtectedInteractor {
            lock.lock(); defer { lock.unlock() }
            if let cached = _benchProtectedInteractor { return cached }
            try _pre_benchProtectedInteractor()
            let value = try BenchProtectedInteractor(session: parent.benchSessionPrecondition(), useCase: benchUseCase())
            _benchProtectedInteractor = value
            return value
        }

        func _pre_benchProtectedInteractor() throws {
            lock.lock(); let built = _benchProtectedInteractor != nil; lock.unlock()
            if built { return }
            _ = try parent.benchSessionPrecondition()
        }

        private var _benchRepositoryProtocol: (any BenchRepositoryProtocol)?
        func benchRepositoryProtocol() -> any BenchRepositoryProtocol {
            lock.lock(); defer { lock.unlock() }
            if let cached = _benchRepositoryProtocol { return cached }
            let value = BenchModuleV1.repository()
            _benchRepositoryProtocol = value
            return value
        }

        func benchUseCase() -> BenchUseCase {
            BenchUseCase(repository: benchRepositoryProtocol())
        }
    }
}
