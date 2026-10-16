import Testing
import DaggerSwift
import AppFoundation
import Core
import Services
import Features
@testable import SampleProyect

@Suite("SampleApp · Unit Tests (Core & Features)")
struct SampleProyectTests {

    @Test("GetProfileUseCase obtiene el perfil de @fsaldivar-dev usando el init generado por @Inject")
    func testGetProfileUseCase() async throws {
        // Ventaja de @Inject: en Unit Tests no necesitas levantar el contenedor si solo pruebas lógica
        let useCase = GetProfileUseCase(gitHubRepository: FakerGitHubRepository())
        let profile = try await useCase.execute()

        #expect(profile.login == "fsaldivar-dev")
        #expect(profile.name == "Saldivar")
    }

    @Test("GetRepositoriesUseCase devuelve el catálogo de repositorios")
    func testGetRepositoriesUseCase() async throws {
        let useCase = GetRepositoriesUseCase(gitHubRepository: FakerGitHubRepository())
        let repos = try await useCase.execute()

        #expect(!repos.isEmpty)
        #expect(repos.contains { $0.name == "dagger-swift" })
    }

    @Test("FeedViewModel filtra repositorios por búsqueda y cambia entre Bento v2 y Compacto v1")
    @MainActor
    func testFeedViewModelSearchAndLayoutToggle() async throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let viewModel = try FeedViewModel(from: container)

        await viewModel.loadInitialData()
        #expect(viewModel.repositories.count >= 5)

        // Filtrado por texto
        viewModel.searchText = "AutoPilot"
        #expect(viewModel.filteredRepositories.count == 1)
        #expect(viewModel.filteredRepositories.first?.name == "AutoPilot")

        // Cambio de layout (@BusinessRule)
        #expect(viewModel.currentStrategy.usesBentoGrid == true)
        viewModel.toggleStrategy()
        #expect(viewModel.currentStrategy.usesBentoGrid == false)
    }

    @Test("FeedViewModel pide iniciar sesión al tocar un repo protegido y lo abre al autenticarse")
    @MainActor
    func testFeedViewModelProtectedRepoFlow() async throws {
        let container = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let viewModel = try FeedViewModel(from: container)

        let protectedRepo = GitHubRepoItem.curatedRepositories.first { $0.isPrivateVault }!

        // 1. Sin sesión: abre el modal de Auth Gate en lugar del detalle
        viewModel.openRepository(protectedRepo)
        #expect(viewModel.activeRepoSession == nil)
        #expect(viewModel.showAuthGateSheet == true)

        // 2. Al iniciar sesión: cierra el Auth Gate y abre automáticamente el repositorio pendiente
        viewModel.login()
        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.showAuthGateSheet == false)
        #expect(viewModel.activeRepoSession?.inspector.repo.name == protectedRepo.name)
    }
}
