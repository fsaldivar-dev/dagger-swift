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

    @Test("Composición del flujo principal: todos los nodos se resuelven", .tags(.graph))
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

    @Test("Precondición con expectWhenCondition: al iniciar sesión se resuelve el detalle", .tags(.precondition))
    func testPrecondicionConExpectWhenCondition() {
        expectWhenCondition(ShowcaseCoreModule.self, FakerGitHubModule.self) { (auth: any AuthRepositoryProtocol) in
            auth.loginAsSaldivar()
        }
        .inChildScope(RepoDetailModule.self, binding: GitHubRepoItem.flagshipDaggerRepo)
        .resolved(ValidatedSession.self)
        .resolved(RepoDetailInspector.self)
        .tornDownCleanly()
    }

    @Test("Precondición antes y después: bloqueado sin sesión y resuelto tras login", .tags(.precondition))
    func testPrecondicionAntesYDespues() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
            .inChildScope(RepoDetailModule.self, binding: GitHubRepoItem.flagshipDaggerRepo)
            .blocked(RepoDetailInspector.self, by: ValidatedSession.self)
            .when { (auth: any AuthRepositoryProtocol) in
                auth.loginAsSaldivar()
            }
            .resolved(ValidatedSession.self)
            .resolved(RepoDetailInspector.self)
            .tornDownCleanly()
    }

    @Test("Regla de negocio (@BusinessRule): cambia de Bento v2 a Compacto v1", .tags(.businessRule))
    func testReglaDeNegocioConWhen() {
        expectGraph(ShowcaseCoreModule.self, FakerGitHubModule.self)
            .resolved((any RepoExplorerStrategyProtocol).self) { $0.usesBentoGrid == true }
            .when { (flags: any FeatureFlagRepositoryProtocol) in
                flags.setBentoV2(false)
            }
            .resolved((any RepoExplorerStrategyProtocol).self) { $0.usesBentoGrid == false }
    }

    @Test("Módulo faltante: sin FakerGitHubModule no se pueden resolver los casos de uso", .tags(.graph))
    func testModuloFaltante() {
        expectGraph(ShowcaseCoreModule.self)
            .unresolved((any GitHubRepositoryProtocol).self)
            .unresolved(GetProfileUseCase.self)
            .unresolved(GetRepositoriesUseCase.self)
    }
}
