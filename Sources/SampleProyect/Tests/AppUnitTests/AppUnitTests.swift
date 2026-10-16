import Testing
import AppFoundation
import Core
import Services
import Features
@testable import SampleProyect

@Suite("1. Pruebas de la App (UseCases y ViewModel)")
struct AppUnitTests {

    @Test("GetProfileUseCase obtiene el perfil de @fsaldivar-dev")
    func testObtenerPerfil() async throws {
        // Gracias a @Inject, podemos instanciar el UseCase directamente con un Fake sin usar el grafo
        let useCase = GetProfileUseCase(gitHubRepository: FakerGitHubRepository())
        let profile = try await useCase.execute()

        #expect(profile.login == "fsaldivar-dev")
        #expect(profile.name == "Saldivar")
    }

    @Test("GetRepositoriesUseCase obtiene la lista de repositorios")
    func testObtenerRepositorios() async throws {
        let useCase = GetRepositoriesUseCase(gitHubRepository: FakerGitHubRepository())
        let repos = try await useCase.execute()

        #expect(!repos.isEmpty)
        #expect(repos.first?.name == "dagger-swift")
    }

    @Test("FeedViewModel filtra repositorios por nombre")
    @MainActor
    func testBuscarRepositorioEnFeed() async throws {
        let graph = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let viewModel = try FeedViewModel(from: graph)

        await viewModel.loadInitialData()
        viewModel.searchText = "AutoPilot"

        #expect(viewModel.filteredRepositories.count == 1)
        #expect(viewModel.filteredRepositories.first?.name == "AutoPilot")
    }
}
