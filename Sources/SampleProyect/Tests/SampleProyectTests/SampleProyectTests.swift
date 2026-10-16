import Testing
import DaggerSwift
@testable import SampleProyect

@Suite("DaggerSwift v2 Clean Architecture & Graph Tests")
struct SampleProyectShowcaseTests {

    @Test("1. Business Rule Node switches between Classic v1 and Bento v2 strategies")
    func testBusinessRuleFeatureFlagSwitching() throws {
        // Directo con la API nativa de DaggerSwift:
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let flags = try container.resolve((any FeatureFlagRepositoryProtocol).self)
        flags.setBentoV2(true)

        let initialStrategy = try container.resolve((any RepoExplorerStrategyProtocol).self)
        #expect(initialStrategy.variant == .bentoV2)
        #expect(initialStrategy.usesBentoGrid == true)

        flags.setBentoV2(false)
        let switchedStrategy = try container.resolve((any RepoExplorerStrategyProtocol).self)
        #expect(switchedStrategy.variant == .classicV1)
        #expect(switchedStrategy.usesBentoGrid == false)
    }

    @Test("2. Precondition Node (ValidatedSession) blocks PrivateVaultModule when logged out and resolves once authenticated")
    func testPreconditionGuardAndResolution() throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])

        // 1. Sin sesión: falla con GraphError.unmetPrecondition
        #expect(throws: GraphError.self) {
            let vaultScope = container.makeChildScope(for: PrivateVaultModule.self)
            _ = try PrivateVaultInteractor.resolve(in: vaultScope)
        }

        // 2. Con sesión: resuelve exitosamente
        let auth = try container.resolve((any AuthRepositoryProtocol).self)
        _ = auth.loginAsSaldivar()

        let vaultScope = container.makeChildScope(for: PrivateVaultModule.self)
        let vault = try PrivateVaultInteractor.resolve(in: vaultScope)
        #expect(vault.session.username == "fsaldivar-dev")
        #expect(vaultScope.activeInstanceCount == 1)

        weak let weakVault: PrivateVaultInteractor? = vault
        _ = consume vault
        let leaks = vaultScope.teardown()
        #expect(leaks.isEmpty)
        #expect(weakVault == nil)
    }

    @Test("3. RepoDetailModule creates child scope and deallocates cleanly with 0 leaks on teardown")
    func testRepoDetailModuleScopeLifecycle() throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let repo = LiveGitHubRepository.flagshipDaggerRepo

        let childScope = container.makeChildScope(for: RepoDetailModule.self)
        childScope.bindInstance(repo)
        let inspector = try RepoDetailInspector.resolve(in: childScope)

        #expect(inspector.repo.name == "dagger-swift")
        #expect(childScope.activeInstanceCount == 1)

        weak let weakInspector: RepoDetailInspector? = inspector
        _ = consume inspector
        let leaks = childScope.teardown()
        #expect(leaks.isEmpty)
        #expect(weakInspector == nil)
    }

    @Test("4. Clean Architecture UseCases execute through Domain and Data boundaries")
    func testCleanArchitectureUseCases() async throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])

        let profileUseCase = try container.resolve(GetProfileUseCase.self)
        let profile = try await profileUseCase.execute()
        #expect(profile.login == "fsaldivar-dev")

        let reposUseCase = try container.resolve(GetRepositoriesUseCase.self)
        let repos = try await reposUseCase.execute()
        #expect(!repos.isEmpty)
        #expect(repos.contains(where: { $0.name == "dagger-swift" }))

        let manifestoUseCase = try container.resolve(GetManifestoChaptersUseCase.self)
        let chapters = manifestoUseCase.execute()
        #expect(chapters.count >= 4)

        let authUseCase = try container.resolve(AuthenticateUseCase.self)
        let logoutUseCase = try container.resolve(LogoutUseCase.self)
        let authRepo = try container.resolve((any AuthRepositoryProtocol).self)

        let session = authUseCase.execute()
        #expect(session.username == "fsaldivar-dev")
        #expect(authRepo.isAuthenticated == true)

        logoutUseCase.execute()
        #expect(authRepo.isAuthenticated == false)
    }

    @Test("5. MVVM ViewModels initialize from Dagger graph container seamlessly")
    @MainActor
    func testMVVMViewModelsInitialization() async throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let coordinator = ShowcaseCoordinator(container: container)

        let homeVM = HomeViewModel(container: container)
        await homeVM.loadProfile()
        #expect(homeVM.profile.login == "fsaldivar-dev")

        let repoVM = RepoExplorerViewModel(container: container)
        await repoVM.loadRepositories()
        #expect(!repoVM.repositories.isEmpty)

        let deepLinksVM = DeepLinksViewModel(container: container)
        #expect(!deepLinksVM.presets.isEmpty)

        let manifestoVM = ManifestoViewModel(container: container)
        #expect(manifestoVM.chapters.count >= 4)

        homeVM.login(coordinator: coordinator)
        #expect(homeVM.isAuthenticated == true)
        #expect(coordinator.eventLogs.contains(where: { $0.category == "Precondition" }))
    }
}
