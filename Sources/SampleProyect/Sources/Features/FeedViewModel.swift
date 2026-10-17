//
//  FeedViewModel.swift
//  Features
//
//  Capa Features · MVVM ViewModel unificado con `@Inject`.
//  Cumple SOLID y Ley de Demeter: solo llama a `execute()` de sus UseCases.
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

    /// Plug & UnPlug: Construye el `FeedViewModel` conectando cualquier `@Module` que cumpla `GitHubServiceModuleContract`.
    public static func plug<M: GitHubServiceModuleContract>(_ module: M.Type) -> FeedViewModel {
        let repo = module.gitHubRepository()
        return FeedViewModel(
            getProfileUseCase: GetProfileUseCase(gitHubRepository: repo),
            getRepositoriesUseCase: GetRepositoriesUseCase(gitHubRepository: repo),
            authRepository: module.authRepository(),
            flagRepository: module.featureFlags()
        )
    }

    public var environmentTitle: String {
        getProfileUseCase.environmentTitle
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
        do {
            async let fetchedProfile = getProfileUseCase.execute()
            async let fetchedRepos = getRepositoriesUseCase.execute()
            self.profile = try await fetchedProfile
            self.repositories = try await fetchedRepos
        } catch {
            self.profile = .fsaldivarDefault
            self.repositories = GitHubRepoItem.curatedRepositories
        }
        refreshStrategy()
    }

    // MARK: - Regla de Negocio (@BusinessRule: Bento v2 vs Compacto v1)

    public func toggleStrategy() {
        let newValue = !currentStrategy.usesBentoGrid
        flagRepository.setBentoV2(newValue)
        refreshStrategy()
    }

    public func refreshStrategy() {
        currentStrategy = ShowcaseCoreModule.explorerStrategy(flags: flagRepository)
    }

    // MARK: - Precondición (@Precondition: ValidatedSession)

    public func toggleAuthentication() {
        isAuthenticated ? logout() : login()
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
        guard let session = ShowcaseCoreModule.validatedSession(auth: authRepository) else {
            pendingRepo = repo
            blockedReason = "Se requiere sesión activa de @fsaldivar-dev para inspeccionar módulos protegidos"
            showAuthGateSheet = true
            return
        }
        let inspector = RepoDetailModule.repoDetailInspector(session: session)
        totalScopesCreated += 1
        activeRepoSession = ActiveRepoSession(repo: repo, inspector: inspector)
    }

    public func closeActiveRepoDetail() {
        guard let session = activeRepoSession else { return }
        session.inspector.onScopeTeardown()
        RepoDetailModule.teardownScope()
        activeRepoSession = nil
        lastLeakAuditCount = 0
        totalScopesTornDown += 1
    }
}
