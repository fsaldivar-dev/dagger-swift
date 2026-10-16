import Testing
import DaggerSwift
@testable import SampleProyect

@Suite("DaggerSwift v2 Showcase Graph Tests")
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

        weak var weakVault = vault
        _ = consume vault
        let leaks = vaultScope.teardown()
        #expect(leaks.isEmpty)
        #expect(weakVault == nil)
    }

    @Test("3. RepoDetailModule creates child scope and deallocates cleanly with 0 leaks on teardown")
    func testRepoDetailModuleScopeLifecycle() throws {
        let assembler = DaggerShowcaseAssembler(environment: FakerGitHubModule.self)
        let repo = LiveGitHubService.flagshipDaggerRepo

        let (scope, inspector) = try assembler.openRepositoryScope(for: repo)
        #expect(inspector.repo.name == "dagger-swift")
        #expect(scope.activeInstanceCount == 1)

        weak var weakInspector = inspector
        _ = consume inspector
        let leaks = scope.teardown()
        #expect(leaks.isEmpty)
        #expect(weakInspector == nil)
    }
}
