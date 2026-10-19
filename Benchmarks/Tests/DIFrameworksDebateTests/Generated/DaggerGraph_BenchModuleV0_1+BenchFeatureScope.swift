// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift

extension DaggerGraph_BenchModuleV0_1 {
    /// Scope `BenchFeatureScope` del grafo [BenchModuleV0_1].
    final class BenchFeatureScopeGraph {
        let parent: DaggerGraph_BenchModuleV0_1
        init(parent: DaggerGraph_BenchModuleV0_1) { self.parent = parent }

        private var _benchRepositoryProtocol: (any BenchRepositoryProtocol)?
        func benchRepositoryProtocol() throws -> any BenchRepositoryProtocol {
            if let cached = _benchRepositoryProtocol { return cached }
            let value = BenchModuleV0_1.repository()
            _benchRepositoryProtocol = value
            return value
        }

        func benchUseCase() throws -> BenchUseCase {
            try BenchUseCase(repository: benchRepositoryProtocol())
        }
    }
}
