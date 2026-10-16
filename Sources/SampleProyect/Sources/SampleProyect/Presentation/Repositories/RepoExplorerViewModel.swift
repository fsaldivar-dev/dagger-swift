//
//  RepoExplorerViewModel.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · MVVM ViewModel
//  Gobierna la consulta de repositorios, búsqueda y resolución de la regla de negocio (@BusinessRule).
//

import Foundation
import SwiftUI
import DaggerSwift

@MainActor
@Inject
public final class RepoExplorerViewModel: ObservableObject {
    private let getRepositoriesUseCase: GetRepositoriesUseCase
    private let toggleVariantUseCase: ToggleExplorerVariantUseCase
    private let container: ScopeContainer

    @Published public var repositories: [GitHubRepoItem] = []
    @Published public var searchText: String = ""
    @Published public var isLoading: Bool = false
    @Published public var currentStrategy: any RepoExplorerStrategyProtocol

    public init(
        getRepositoriesUseCase: GetRepositoriesUseCase,
        toggleVariantUseCase: ToggleExplorerVariantUseCase,
        currentStrategy: any RepoExplorerStrategyProtocol,
        container: ScopeContainer
    ) {
        self.getRepositoriesUseCase = getRepositoriesUseCase
        self.toggleVariantUseCase = toggleVariantUseCase
        self.currentStrategy = currentStrategy
        self.container = container
    }

    public var filteredRepositories: [GitHubRepoItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return repositories }
        return repositories.filter {
            $0.name.lowercased().contains(query) ||
            $0.description.lowercased().contains(query) ||
            $0.language.lowercased().contains(query)
        }
    }

    public func loadRepositories() async {
        guard repositories.isEmpty else { return }
        await refresh()
    }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.repositories = try await getRepositoriesUseCase.execute()
        } catch {
            self.repositories = LiveGitHubRepository.curatedRepositories
        }
        refreshStrategy()
    }

    public func refreshStrategy() {
        if let updated = try? container.resolve((any RepoExplorerStrategyProtocol).self) {
            self.currentStrategy = updated
        }
    }

    public func toggleStrategy(coordinator: ShowcaseCoordinator) {
        let newValue = !currentStrategy.usesBentoGrid
        toggleVariantUseCase.execute(enableBentoV2: newValue)
        refreshStrategy()
        coordinator.appendLog(
            category: "BusinessRule",
            message: "Regla de negocio evaluada dinámicamente: `\(currentStrategy.variant.rawValue)`."
        )
    }
}
