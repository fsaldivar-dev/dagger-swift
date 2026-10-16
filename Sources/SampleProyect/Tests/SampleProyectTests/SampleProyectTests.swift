import Testing
import DaggerSwift
@testable import SampleProyect

@Suite("DaggerSwift v2 Clean Architecture & Graph Tests")
struct SampleProyectShowcaseTests {

    @Test("1. Business Rule Node switches between Classic v1 and Bento v2 strategies")
    func testBusinessRuleFeatureFlagSwitching() throws {
        let assembler = DaggerShowcaseAssembler(
            environment: FakerGitHubModule.self,
            initiallyAuthenticated: false,
            initialBentoV2Flag: true
        )

        let initialStrategy = try assembler.rootContainer.resolve((any RepoExplorerStrategyProtocol).self)
        #expect(initialStrategy.variant == .bentoV2)
        #expect(initialStrategy.usesBentoGrid == true)

        assembler.featureFlagBox.setBentoV2(false)
        let switchedStrategy = try assembler.rootContainer.resolve((any RepoExplorerStrategyProtocol).self)
        #expect(switchedStrategy.variant == .classicV1)
        #expect(switchedStrategy.usesBentoGrid == false)
    }

    @Test("2. Precondition Node (ValidatedSession) blocks PrivateVaultModule when logged out and resolves once authenticated")
    func testPreconditionGuardAndResolution() throws {
        let assembler = DaggerShowcaseAssembler(
            environment: FakerGitHubModule.self,
            initiallyAuthenticated: false
        )

        #expect(throws: GraphError.self) {
            _ = try assembler.openPrivateVaultScope()
        }

        _ = assembler.authBox.loginAsSaldivar()
        let (vaultScope, vault) = try assembler.openPrivateVaultScope()
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
        let assembler = DaggerShowcaseAssembler(environment: FakerGitHubModule.self)
        let repo = LiveGitHubRepository.flagshipDaggerRepo

        let (scope, inspector) = try assembler.openRepositoryScope(for: repo)
        #expect(inspector.repo.name == "dagger-swift")
        #expect(scope.activeInstanceCount == 1)

        weak let weakInspector: RepoDetailInspector? = inspector
        _ = consume inspector
        let leaks = scope.teardown()
        #expect(leaks.isEmpty)
        #expect(weakInspector == nil)
    }

    @Test("4. Clean Architecture UseCases execute through Domain and Data boundaries")
    func testCleanArchitectureUseCases() async throws {
        let assembler = DaggerShowcaseAssembler(environment: FakerGitHubModule.self)
        let container = assembler.rootContainer

        // Test GetProfileUseCase
        let profileUseCase = try container.resolve(GetProfileUseCase.self)
        let profile = try await profileUseCase.execute()
        #expect(profile.login == "fsaldivar-dev")

        // Test GetRepositoriesUseCase
        let reposUseCase = try container.resolve(GetRepositoriesUseCase.self)
        let repos = try await reposUseCase.execute()
        #expect(!repos.isEmpty)
        #expect(repos.contains(where: { $0.name == "dagger-swift" }))

        // Test ManifestoUseCase
        let manifestoUseCase = try container.resolve(GetManifestoChaptersUseCase.self)
        let chapters = manifestoUseCase.execute()
        #expect(chapters.count >= 4)

        // Test Auth UseCases
        let authUseCase = try container.resolve(AuthenticateUseCase.self)
        let logoutUseCase = try container.resolve(LogoutUseCase.self)
        let session = authUseCase.execute()
        #expect(session.username == "fsaldivar-dev")
        #expect(assembler.authBox.isAuthenticated == true)

        logoutUseCase.execute()
        #expect(assembler.authBox.isAuthenticated == false)
    }

    @Test("5. MVVM ViewModels initialize from Dagger graph container seamlessly")
    @MainActor
    func testMVVMViewModelsInitialization() async throws {
        let assembler = DaggerShowcaseAssembler(environment: FakerGitHubModule.self)
        let container = assembler.rootContainer
        let coordinator = ShowcaseCoordinator(assembler: assembler)

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

        // Simulate login through ViewModel
        homeVM.login(coordinator: coordinator)
        #expect(homeVM.isAuthenticated == true)
        #expect(coordinator.eventLogs.contains(where: { $0.category == "Precondition" }))
    }
}
