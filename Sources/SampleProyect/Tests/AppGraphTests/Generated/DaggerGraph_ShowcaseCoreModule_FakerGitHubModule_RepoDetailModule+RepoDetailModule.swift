// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import AppFoundation
import Core
import DaggerSwift
import Features
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

extension DaggerGraph_ShowcaseCoreModule_FakerGitHubModule_RepoDetailModule {
    /// Scope `RepoDetailModule` del grafo [ShowcaseCoreModule, LiveGitHubModule, FakerGitHubModule, RepoDetailModule].
    @MainActor
    final class RepoDetailModuleGraph {
        let parent: DaggerGraph_ShowcaseCoreModule_FakerGitHubModule_RepoDetailModule
        init(parent: DaggerGraph_ShowcaseCoreModule_FakerGitHubModule_RepoDetailModule) { self.parent = parent }

        private var _repoDetailInspector: RepoDetailInspector?
        func repoDetailInspector() throws -> RepoDetailInspector {
            if let cached = _repoDetailInspector { return cached }
            let value = try RepoDetailModule.repoDetailInspector(session: parent.validatedSession())
            _repoDetailInspector = value
            return value
        }
    }
}
