//
//  FeedViewModel.swift
//  Features
//
//  Capa Features · MVVM ViewModel unificado con @Inject.
//  Observa que NO requiere escribir un `init` manual: la macro @Inject genera
//  tanto el `init` para pruebas unitarias como `init(from container:) throws`.
//

import Foundation
import SwiftUI
import DaggerSwift
import AppFoundation
import Core

@MainActor
@Inject
public final class FeedViewModel: ObservableObject {
    public let getProfileUseCase: GetProfileUseCase
    public let getRepositoriesUseCase: GetRepositoriesUseCase
    public let authRepository: any AuthRepositoryProtocol
    public let flagRepository: any FeatureFlagRepositoryProtocol
    public let container: ScopeContainer

    @Published public var profile: GitHubUserProfile = .fsaldivarDefault
    @Published public var repositories: [GitHubRepoItem] = []
    @Published public var searchText: String = ""
    @Published public var isAuthenticated: Bool = false
    @Published public var currentStrategy: any RepoExplorerStrategyProtocol = RepoExplorerStrategy.bento
    @Published public var isLoading: Bool = false

    // Estado de Navegación Scoped y Precondición
    @Published public var activeRepoSession: ActiveRepoSession?
    @Published public var showAuthGateSheet: Bool = false
    @Published public var blockedReason: String?
    @Published public var totalScopesCreated: Int = 1
    @Published public var totalScopesTornDown: Int = 0
    @Published public var lastLeakAuditCount: Int = 0
    private var pendingRepo: GitHubRepoItem? = nil

    public var environmentTitle: String {
        getProfileUseCase.gitHubRepository.environmentTitle
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

    // MARK: - Carga de Datos (UseCases)

    public func loadInitialData() async {
        isAuthenticated = authRepository.isAuthenticated
        refreshStrategy()
        await refresh()
    }

    public func refresh() async {
        isLoading = true
        defer { isLoading = false }
        async let fetchedProfile = getProfileUseCase.execute()
        async let fetchedRepos = getRepositoriesUseCase.execute()
        self.profile = (try? await fetchedProfile) ?? .fsaldivarDefault
        self.repositories = (try? await fetchedRepos) ?? GitHubRepoItem.curatedRepositories
        refreshStrategy()
    }

    // MARK: - Regla de Negocio (@BusinessRule: Bento v2 vs Compacto v1)

    public func toggleStrategy() {
        let newValue = !currentStrategy.usesBentoGrid
        flagRepository.setBentoV2(newValue)
        refreshStrategy()
    }

    public func refreshStrategy() {
        if let updated = try? container.resolve((any RepoExplorerStrategyProtocol).self) {
            currentStrategy = updated
        }
    }

    // MARK: - Precondición (@Precondition: ValidatedSession)

    public func toggleAuthentication() {
        if isAuthenticated {
            logout()
        } else {
            login()
        }
    }

    public func login() {
        _ = authRepository.loginAsSaldivar()
        isAuthenticated = true
        showAuthGateSheet = false
        blockedReason = nil
        if let repo = pendingRepo {
            pendingRepo = nil
            openRepository(repo)
        }
    }

    public func logout() {
        closeActiveRepoDetail()
        authRepository.logout()
        isAuthenticated = false
    }

    // MARK: - Sub-Scope de Detalle (`RepoDetailModule`)

    public func openRepository(_ repo: GitHubRepoItem) {
        closeActiveRepoDetail()
        let childScope = container.makeChildScope(for: RepoDetailModule.self)
        childScope.bindInstance(repo)

        do {
            let inspector: RepoDetailInspector
            if repo.isPrivateVault {
                // Exige ValidatedSession (@Precondition) antes de crear el inspector
                inspector = try ProtectedRepoAccess.resolve(in: childScope).inspector
            } else {
                inspector = try RepoDetailInspector.resolve(in: childScope)
            }
            totalScopesCreated += 1
            activeRepoSession = ActiveRepoSession(scope: childScope, inspector: inspector)
        } catch let GraphError.unmetPrecondition(_, reason) {
            childScope.teardown()
            pendingRepo = repo
            blockedReason = reason
            showAuthGateSheet = true
        } catch {
            childScope.teardown()
        }
    }

    public func closeActiveRepoDetail() {
        guard let scope = activeRepoSession?.scope else { return }
        activeRepoSession = nil
        lastLeakAuditCount = scope.teardown().count
        totalScopesTornDown += 1
    }
}
