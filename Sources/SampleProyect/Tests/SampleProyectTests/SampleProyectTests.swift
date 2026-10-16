import Testing
import DaggerSwift
import DaggerSwiftTesting
import AppFoundation
import Core
import Services
import Features
@testable import SampleProyect

@Suite("SampleProyect · Auditoría de Grafo, Precondiciones y Lógica (DaggerSwiftTesting)")
struct SampleProyectTests {

    // MARK: - 1. Auditoría de @Precondition (Con JSON y Comparativa Adjunta)

    @Test(
        "Precondición ValidatedSession: Bloquea RepoDetailInspector sin sesión (0 RAM) y lo permite tras login",
        .tags(.preconditionGuard, .scopeLifecycle)
    )
    func testPreconditionAuditWithComparisonAttachment() throws {
        let root = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let auth = try root.resolve((any AuthRepositoryProtocol).self)

        // Audita automáticamente el ANTES (sin sesión) vs DESPUÉS (con sesión)
        // y adjunta `repo-detail-precondition.json` y `repo-detail-precondition-summary.txt` al reporte del test
        let audit = try root.auditPrecondition(
            resolving: RepoDetailInspector.self,
            guardedBy: ValidatedSession.self,
            in: {
                let child = root.makeChildScope(for: RepoDetailModule.self)
                child.bindInstance(GitHubRepoItem.flagshipDaggerRepo)
                return child
            },
            unlockAction: {
                auth.loginAsSaldivar()
            },
            attachmentPrefix: "repo-detail-precondition"
        )

        // Sin sesión: el grafo abortó en ValidatedSession y creó 0 objetos en RepoDetailModule
        #expect(audit.whenBlocked.activeInstancesInScope == 0)
        #expect(audit.whenBlocked.failureTrace.last?.contains("ValidatedSession") == true)

        // Con sesión: el grafo permitió construir RepoDetailInspector (1 objeto vivo en el sub-scope)
        #expect(audit.whenUnlocked.activeInstancesInScope == 1)
    }

    // MARK: - 2. Topología del Grafo (Exportación JSON + Diagrama Mermaid)

    @Test(
        "Topología del Grafo: Exporta el árbol GlobalScope -> RepoDetailModule en JSON y Mermaid",
        .tags(.graphTopology, .businessRuleBranch)
    )
    @MainActor
    func testGraphTopologyAttachments() throws {
        let root = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let auth = try root.resolve((any AuthRepositoryProtocol).self)
        auth.loginAsSaldivar()

        // Resolvemos el ViewModel principal y abrimos un sub-scope hijo
        let viewModel = try FeedViewModel(from: root)
        viewModel.openRepository(.flagshipDaggerRepo)

        // Adjunta el JSON del grafo jerárquico y su diagrama Mermaid al reporte del test en Xcode
        let snapshot = root.attachGraphJSON(named: "sample-app-graph.json")
        let mermaid = root.attachMermaidDiagram(named: "sample-app-graph.mmd")

        #expect(snapshot.scope.contains("GlobalScope"))
        #expect(snapshot.children.count == 1)
        #expect(snapshot.children.first?.scope.contains("RepoDetailModule") == true)
        #expect(mermaid.contains("RepoDetailInspector"))

        viewModel.closeActiveRepoDetail()
        #expect(viewModel.lastLeakAuditCount == 0)
    }

    // MARK: - 3. Comparativa cuando el Grafo se Rompe (Fault Injection)

    @Test(
        "Comparativa de Fallo: Detecta exactamente qué dependencia falta cuando un módulo no se registró",
        .tags(.faultComparison)
    )
    func testBrokenGraphComparisonAttachment() {
        // Creamos un contenedor con ShowcaseCoreModule pero SIN el módulo de servicios (FakerGitHubModule)
        let brokenRoot = ShowcaseCoreModule.buildGraph(including: [])

        let faultReport = brokenRoot.auditExpectedFault(
            scenario: "Olvidamos registrar FakerGitHubModule / LiveGitHubModule",
            resolving: GetProfileUseCase.self,
            expectedBehavior: "Abortar indicando la cadena GetProfileUseCase -> GitHubRepositoryProtocol",
            attachmentPrefix: "missing-service-module-fault"
        )

        #expect(faultReport.brokenChain.count == 2)
        #expect(faultReport.brokenChain.first?.contains("GetProfileUseCase") == true)
        #expect(faultReport.brokenChain.last?.contains("GitHubRepositoryProtocol") == true)
        #expect(faultReport.activeInstancesAfterAbort == 0)
    }

    // MARK: - 4. Unit Tests Puros de la App (Usando el init sintetizado por @Inject)

    @Test("Unit Test aislado de GetProfileUseCase y FeedViewModel")
    @MainActor
    func testPureDomainAndViewModelLogic() async throws {
        let useCase = GetProfileUseCase(gitHubRepository: FakerGitHubRepository())
        let profile = try await useCase.execute()
        #expect(profile.login == "fsaldivar-dev")

        let root = ShowcaseCoreModule.buildGraph(including: [FakerGitHubModule.self])
        let viewModel = try FeedViewModel(from: root)
        await viewModel.loadInitialData()

        // 1. Al tocar cualquier repo sin haber iniciado sesión, @Precondition abre el Auth Gate
        viewModel.openRepository(.flagshipDaggerRepo)
        #expect(viewModel.activeRepoSession == nil)
        #expect(viewModel.showAuthGateSheet == true)

        // 2. Al autenticarse, se cumple ValidatedSession y se abre el detalle automáticamente
        viewModel.login()
        #expect(viewModel.isAuthenticated == true)
        #expect(viewModel.showAuthGateSheet == false)
        #expect(viewModel.activeRepoSession?.inspector.repo.name == "dagger-swift")
    }
}
