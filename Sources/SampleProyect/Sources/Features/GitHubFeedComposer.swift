//
//  GitHubFeedComposer.swift
//  Features · Composition Root (SOLID)
//
//  Responsabilidad Única (SRP + DIP): Ensambla `FeedView` y `FeedViewModel` a partir
//  de cualquier módulo que cumpla `GitHubServiceModuleContract` (ej. `LiveGitHubModule` v1,
//  `LiveGitHubModuleV2` v2 o `FakerGitHubModule` en Tests).
//

import SwiftUI
import DaggerSwift
import AppFoundation
import Core

public enum GitHubFeedComposer {
    @MainActor
    public static func makeViewModel<M: GitHubServiceModuleContract>(
        module: M.Type
    ) -> FeedViewModel {
        let gitHubRepo = module.gitHubRepository()
        return FeedViewModel(
            getProfileUseCase: GetProfileUseCase(gitHubRepository: gitHubRepo),
            getRepositoriesUseCase: GetRepositoriesUseCase(gitHubRepository: gitHubRepo),
            authRepository: module.authRepository(),
            flagRepository: module.featureFlags()
        )
    }

    @MainActor
    public static func compose<M: GitHubServiceModuleContract>(
        module: M.Type
    ) -> FeedView {
        FeedView(viewModel: makeViewModel(module: module))
    }
}
