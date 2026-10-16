import Testing
import DaggerSwift
import AppFoundation
import Core
import Services
import Features
@testable import SampleProyect

@Suite("DaggerSwift v2 · 4-Layer SPM Architecture Tests")
struct SampleProyectShowcaseTests {

    @Test("1. @BusinessRule switches dynamically between Bento v2 and Classic v1")
    func testBusinessRuleFeatureFlagSwitching() throws {
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

    @Test("2. @Precondition (ValidatedSession) blocks ProtectedRepoAccess when logged out and resolves once authenticated")
    func testPreconditionGuardAndResolution() throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let repo = GitHubRepoItem.flagshipDaggerRepo

        // 1. Sin sesión: falla con GraphError.unmetPrecondition
        #expect(throws: GraphError.self) {
            let childScope = container.makeChildScope(for: RepoDetailModule.self)
            childScope.bindInstance(repo)
            _ = try ProtectedRepoAccess.resolve(in: childScope)
        }

        // 2. Con sesión: resuelve exitosamente
        let auth = try container.resolve((any AuthRepositoryProtocol).self)
        _ = auth.loginAsSaldivar()

        let childScope = container.makeChildScope(for: RepoDetailModule.self)
        childScope.bindInstance(repo)
        let protected = try ProtectedRepoAccess.resolve(in: childScope)
        #expect(protected.session.username == "fsaldivar-dev")
        #expect(protected.inspector.repo.name == "dagger-swift")
    }

    @Test("3. RepoDetailModule creates child scope and deallocates cleanly with 0 leaks on teardown")
    func testRepoDetailModuleScopeLifecycle() throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let repo = GitHubRepoItem.flagshipDaggerRepo

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

    @Test("4. @Inject UseCases auto-resolve without manual registration in @Module")
    func testAutoResolvedUseCases() async throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])

        let profileUseCase = try container.resolve(GetProfileUseCase.self)
        let profile = try await profileUseCase.execute()
        #expect(profile.login == "fsaldivar-dev")

        let reposUseCase = try container.resolve(GetRepositoriesUseCase.self)
        let repos = try await reposUseCase.execute()
        #expect(!repos.isEmpty)
        #expect(repos.contains(where: { $0.name == "dagger-swift" }))
    }

    @Test("5. @Inject FeedViewModel initializes from Dagger graph without manual init")
    @MainActor
    func testFeedViewModelInitialization() async throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let vm = try FeedViewModel(from: container)

        await vm.loadInitialData()
        #expect(vm.profile.login == "fsaldivar-dev")
        #expect(!vm.repositories.isEmpty)

        // Abrir repo público abre el sheet de detalle
        vm.openRepository(.flagshipDaggerRepo)
        #expect(vm.activeRepoSession != nil)
        vm.closeActiveRepoDetail()
        #expect(vm.activeRepoSession == nil)
        #expect(vm.lastLeakAuditCount == 0)
    }

    @Test("6. Throwing init(from:) fails cleanly with GraphError when dependency is missing")
    @MainActor
    func testViewModelThrowsOnMissingDependency() {
        let emptyContainer = ScopeContainer.root(modules: [])
        #expect(throws: GraphError.self) {
            _ = try FeedViewModel(from: emptyContainer)
        }
    }

    @Test("7. Synthesized init from @Inject works for isolated unit testing without container")
    func testSynthesizedConstructorInjection() async throws {
        let fakeRepo = FakerGitHubRepository()
        let useCase = GetProfileUseCase(gitHubRepository: fakeRepo)
        let profile = try await useCase.execute()
        #expect(profile.login == "fsaldivar-dev")
    }
}
