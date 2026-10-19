// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import Foundation

extension DaggerGraph_NestedAppModule {
    /// Scope `NestedFeatureScope` del grafo [NestedAppModule].
    final class NestedFeatureScopeGraph: @unchecked Sendable {
        let parent: NestedSessionScopeGraph
        init(parent: NestedSessionScopeGraph) { self.parent = parent }
        var lock: NSRecursiveLock { parent.lock }

        private var _nestedFeatureViewModel: NestedFeatureViewModel?
        func nestedFeatureViewModel() throws -> NestedFeatureViewModel {
            lock.lock(); defer { lock.unlock() }
            if let cached = _nestedFeatureViewModel { return cached }
            let value = try NestedFeatureViewModel(report: parent.nestedHeavyReport(), gate: parent.parent.nestedSessionGate())
            _nestedFeatureViewModel = value
            return value
        }
    }
}
