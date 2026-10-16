import Testing
import DaggerSwift
import DaggerSwiftTesting
import AppFoundation
import Core
import Services
import Features
@testable import SampleProyect

@Suite("2. Pruebas del Grafo de Dependencias (Precondiciones y Módulos)")
struct AppGraphTests {

    @Test("Precondición (Caso 1 - Sin Sesión): El grafo bloquea RepoDetailInspector porque no hay login", .tags(.precondition))
    func testSinSesionBloqueaDetalle() {
        let graph = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let detailScope = graph.makeChildScope(for: RepoDetailModule.self)
        detailScope.bindInstance(GitHubRepoItem.flagshipDaggerRepo)

        do {
            // Intentamos crear RepoDetailInspector SIN haber iniciado sesión
            _ = try detailScope.resolve(RepoDetailInspector.self)
            Issue.record("No debería crearse sin sesión")
        } catch {
            // Adjunta un JSON simple mostrando dónde se detuvo: "RepoDetailInspector -> ❌ ValidatedSession"
            let reporte = detailScope.attachErrorJSON(
                for: RepoDetailInspector.self,
                error: error,
                named: "1-bloqueado-sin-sesion.json"
            )
            #expect(reporte.caminoRecorrido == "RepoDetailInspector -> ❌ ValidatedSession")
            #expect(reporte.objetosCreadosEnRAM == 0)
        }
    }

    @Test("Precondición (Caso 2 - Con Sesión): Al hacer login, el grafo sí construye RepoDetailInspector", .tags(.precondition, .graph))
    func testConSesionPermiteDetalle() throws {
        let graph = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])

        // 1. Iniciamos sesión
        let auth = try graph.resolve((any AuthRepositoryProtocol).self)
        auth.loginAsSaldivar()

        // 2. Ahora pedimos RepoDetailInspector y sí se construye
        let detailScope = graph.makeChildScope(for: RepoDetailModule.self)
        detailScope.bindInstance(GitHubRepoItem.flagshipDaggerRepo)
        let inspector = try detailScope.resolve(RepoDetailInspector.self)

        // Adjunta el JSON del grafo mostrando todas las conexiones activas
        let grafoJSON = graph.attachGraphJSON(named: "2-grafo-con-sesion-activa.json")

        #expect(inspector.session.username == "fsaldivar-dev")
        #expect(grafoJSON.subScopes.first?.objetosVivosEnRAM == 1)
    }

    @Test("Grafo Roto: Si olvidamos registrar FakerGitHubModule, indica qué dependencia falta", .tags(.graph))
    func testFaltaModuloEnElGrafo() {
        // Armamos el grafo SIN FakerGitHubModule
        let incompleteGraph = ShowcaseCoreModule.buildGraph(including: [])

        do {
            _ = try incompleteGraph.resolve(GetProfileUseCase.self)
            Issue.record("Debió fallar porque falta el módulo de servicios")
        } catch {
            // Adjunta un JSON simple mostrando qué faltó: "GetProfileUseCase -> ❌ GitHubRepositoryProtocol"
            let reporte = incompleteGraph.attachErrorJSON(
                for: GetProfileUseCase.self,
                error: error,
                named: "3-error-falta-modulo.json"
            )
            #expect(reporte.caminoRecorrido == "GetProfileUseCase -> ❌ GitHubRepositoryProtocol")
        }
    }
}
