// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import AppFoundation
import Core
import DaggerSwift
import Features
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

extension DaggerGraph_ShowcaseCoreModule_FakerGitHubModule {
    /// Scope `RepoDetailModule` del grafo [ShowcaseCoreModule, LiveGitHubModule, FakerGitHubModule].
    @MainActor
    final class RepoDetailModuleGraph {
        let parent: DaggerGraph_ShowcaseCoreModule_FakerGitHubModule
        init(parent: DaggerGraph_ShowcaseCoreModule_FakerGitHubModule) { self.parent = parent }

        private var _repoDetailInspector: RepoDetailInspector?
        func repoDetailInspector() throws -> RepoDetailInspector {
            if let cached = _repoDetailInspector { return cached }
            let value = try RepoDetailInspector(session: parent.validatedSession())
            _repoDetailInspector = value
            return value
        }
    }
}
