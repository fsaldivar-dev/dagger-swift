import Testing
import DaggerSwift
import DaggerSwiftTesting
import AppFoundation
import Core
import Services
import Features
@testable import SampleProyect

@Suite("2. Pruebas del Grafo de Dependencias")
struct AppGraphTests {

    @Test("Inyectar Fakes al vuelo con whenResolved(...).returns(Fake.self)", .tags(.graph))
    @MainActor
    func testWhenResolvedReturnsFake() {
        ShowcaseCoreModule
            .whenResolved((any GitHubRepositoryProtocol).self).returns(FakerGitHubRepository.self)
            .whenResolved((any AuthRepositoryProtocol).self).returns(AuthSessionRepository.self)
            .whenResolved((any FeatureFlagRepositoryProtocol).self).returns(FeatureFlagRepositoryImpl.self)
            .resolved(GetProfileUseCase.self)
            .resolved(GetRepositoriesUseCase.self)
            .resolved(FeedViewModel.self)
    }

    @Test("Composición completa con módulos: expectGraph(...).resolved(...)", .tags(.graph))
    @MainActor
    func testComposicionFlujoPrincipal() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
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

    @Test("Módulo faltante: sin FakerGitHubModule falla con unresolvedFailure()", .tags(.graph))
    func testModuloFaltante() {
        expectGraph(ShowcaseCoreModule.self)
            .dependency((any GitHubRepositoryProtocol).self).unresolvedFailure()
            .dependency(GetProfileUseCase.self).unresolvedFailure()
            .dependency(GetRepositoriesUseCase.self).unresolvedFailure()
    }
}
