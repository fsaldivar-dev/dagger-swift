import Testing
import DaggerSwift
import DaggerSwiftTesting
import AppFoundation
import Core
import Services
import Features
@testable import SampleProyect

// MARK: - Fake exclusivo del Target de Tests (Cero Fakes en Release)

@Inject
final class FakerGitHubRepository: GitHubRepositoryProtocol, Sendable {
    let environmentTitle: String = "SANDBOX · Faker Offline"
    let isFakerEnvironment: Bool = true

    func fetchProfile(username: String) async throws -> GitHubUserProfile {
        .fsaldivarDefault
    }

    func fetchRepositories(username: String) async throws -> [GitHubRepoItem] {
        GitHubRepoItem.curatedRepositories
    }
}

/// Hereda `authRepository()` y `featureFlags()` de `LiveGitHubModule`
/// y solo reemplaza `gitHubRepository()` para pruebas offline.
@Module(includes: [LiveGitHubModule.self])
enum FakerGitHubModule {
    @Singleton
    static func gitHubRepository() -> any GitHubRepositoryProtocol {
        FakerGitHubRepository()
    }
}

// MARK: - Pruebas del Grafo de Dependencias

@Suite("2. Pruebas del Grafo de Dependencias")
struct AppGraphTests {

    @Test("Inyectar Fakes al vuelo con whenResolved(...).returns(Fake.self)", .tags(.graph))
    @MainActor
    func testWhenResolvedReturnsFake() {
        expectGraph(ShowcaseCoreModule.self, LiveGitHubModule.self)
            .whenResolved((any GitHubRepositoryProtocol).self).returns(FakerGitHubRepository.self)
            .resolved(GetProfileUseCase.self)
            .resolved(GetRepositoriesUseCase.self)
            .resolved(FeedViewModel.self)
    }

    @Test("Variantes de Módulo: LiveGitHubModuleV2 conserva Network de V1 y actualiza Login a V2", .tags(.graph))
    func testVarianteDeModuloConIncludesYMatchesContract() {
        expectGraph(ShowcaseCoreModule.self, LiveGitHubModuleV2.self)
            .matchesContract(of: LiveGitHubModule.self)
            .dependency((any GitHubRepositoryProtocol).self).resolved { $0.isFakerEnvironment == false }
            .when { (auth: any AuthRepositoryProtocol) in
                auth.loginAsSaldivar()
            }
            .dependency(ValidatedSession.self).resolved { $0.tokenFingerprint.hasPrefix("OAUTH-V2-") }
    }

    @Test("Composición completa con módulos: expectGraph(...).resolved(...)", .tags(.graph))
    @MainActor
    func testComposicionFlujoPrincipal() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
            .matchesContract(of: LiveGitHubModule.self)
            .resolved((any GitHubRepositoryProtocol).self)
            .resolved((any AuthRepositoryProtocol).self)
            .resolved((any FeatureFlagRepositoryProtocol).self)
            .resolved((any RepoExplorerStrategyProtocol).self)
            .resolved(GetProfileUseCase.self)
            .resolved(GetRepositoriesUseCase.self)
            .resolved(FeedViewModel.self)
    }

    @Test("Precondición: sin sesión falla con preconditionFailure() y tras login se resuelve", .tags(.precondition))
    func testPrecondicionSinNavegarScopes() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self, RepoDetailModule.self)
            .whenResolved(GitHubRepoItem.self).returns(.flagshipDaggerRepo)
            .dependency(GetProfileUseCase.self).hasNoPreconditions()
            .dependency(RepoDetailInspector.self).preconditionFailure()
            .when { (auth: any AuthRepositoryProtocol) in
                auth.loginAsSaldivar()
            }
            .dependency(ValidatedSession.self).resolved()
            .dependency(RepoDetailInspector.self).resolved()
    }

    @Test("Precondición directa con expectWhenCondition", .tags(.precondition))
    func testPrecondicionConExpectWhenCondition() {
        expectWhenCondition(ShowcaseCoreModule.self, FakerGitHubModule.self, RepoDetailModule.self) { (auth: any AuthRepositoryProtocol) in
            auth.loginAsSaldivar()
        }
        .whenResolved(GitHubRepoItem.self).returns(.flagshipDaggerRepo)
        .dependency(ValidatedSession.self).resolved()
        .dependency(RepoDetailInspector.self).resolved()
    }

    @Test("Regla de negocio (@BusinessRule): cambia de Bento v2 a Compacto v1", .tags(.businessRule))
    func testReglaDeNegocioConWhen() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
            .dependency((any RepoExplorerStrategyProtocol).self).resolved { $0.usesBentoGrid == true }
            .when { (flags: any FeatureFlagRepositoryProtocol) in
                flags.setBentoV2(false)
            }
            .dependency((any RepoExplorerStrategyProtocol).self).resolved { $0.usesBentoGrid == false }
    }

    @Test("Módulo faltante: sin módulo de servicios falla con unresolvedFailure()", .tags(.graph))
    func testModuloFaltante() {
        expectGraph(ShowcaseCoreModule.self)
            .dependency((any GitHubRepositoryProtocol).self).unresolvedFailure()
            .dependency(GetProfileUseCase.self).unresolvedFailure()
            .dependency(GetRepositoriesUseCase.self).unresolvedFailure()
    }
}
