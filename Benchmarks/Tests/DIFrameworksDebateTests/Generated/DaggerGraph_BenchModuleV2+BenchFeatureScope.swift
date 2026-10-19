// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift

extension DaggerGraph_BenchModuleV2 {
    /// Scope `BenchFeatureScope` del grafo [BenchModuleV0_1, BenchModuleV1, BenchModuleV2].
    final class BenchFeatureScopeGraph {
        let parent: DaggerGraph_BenchModuleV2
        init(parent: DaggerGraph_BenchModuleV2) { self.parent = parent }

        private var _benchProtectedInteractor: BenchProtectedInteractor?
        func benchProtectedInteractor() throws -> BenchProtectedInteractor {
            if let cached = _benchProtectedInteractor { return cached }
            let value = try BenchProtectedInteractor(session: parent.benchSessionPrecondition(), useCase: benchUseCase())
            _benchProtectedInteractor = value
            return value
        }

        private var _benchRepositoryProtocol: (any BenchRepositoryProtocol)?
        func benchRepositoryProtocol() throws -> any BenchRepositoryProtocol {
            if let cached = _benchRepositoryProtocol { return cached }
            let value = BenchModuleV1.repository()
            _benchRepositoryProtocol = value
            return value
        }

        func benchUseCase() throws -> BenchUseCase {
            try BenchUseCase(repository: benchRepositoryProtocol())
        }
    }
}
