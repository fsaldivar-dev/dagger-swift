// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import Foundation

extension DaggerGraph_NestedAppModule {
    /// Scope `NestedSessionScope` del grafo [NestedAppModule].
    final class NestedSessionScopeGraph: @unchecked Sendable {
        let parent: DaggerGraph_NestedAppModule
        init(parent: DaggerGraph_NestedAppModule) { self.parent = parent }
        var lock: NSRecursiveLock { parent.lock }

        /// Abre el scope hijo `NestedFeatureScope`.
        func makeNestedFeatureScope() -> NestedFeatureScopeGraph { NestedFeatureScopeGraph(parent: self) }

        func nestedHeavyReport() throws -> NestedHeavyReport {
            try NestedHeavyReport(store: nestedSessionStore())
        }

        private var _nestedSessionStore: NestedSessionStore?
        func nestedSessionStore() throws -> NestedSessionStore {
            lock.lock(); defer { lock.unlock() }
            if let cached = _nestedSessionStore { return cached }
            let value = try NestedAppModule.store(api: parent.nestedApiClient())
            _nestedSessionStore = value
            return value
        }
    }
}
