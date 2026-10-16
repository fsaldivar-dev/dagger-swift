//
//  DaggerShowcaseCoordinator.swift
//  SampleProyect
//
//  Coordinador de Navegación y Estado de Presentación.
//  Respeta estrictamente la regla arquitectónica de DaggerSwift v2:
//  - El Grafo (DaggerShowcaseAssembler) SOLO construye dependencias y valida precondiciones.
//  - El Coordinador (DaggerShowcaseCoordinator) captura GraphError.unmetPrecondition y decide la navegación.
//

import Foundation
import SwiftUI
import DaggerSwift

public enum ShowcaseTab: String, CaseIterable, Identifiable, Sendable {
    case repositories = "Repositorios"
    case deepLinks    = "Deep Links & Auth"
    case manifesto    = "Manifiesto"
    case graphMonitor = "Grafo & RAM"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .repositories: return "shippingbox.fill"
        case .deepLinks:    return "link.badge.plus"
        case .manifesto:    return "book.pages.fill"
        case .graphMonitor: return "point.3.connected.trianglepath.dotted"
        }
    }
}

public struct ActiveRepoSession: Identifiable {
    public var id: String { inspector.instanceID }
    public let scope: ScopeContainer
    public let inspector: RepoDetailInspector
}

public struct ActiveVaultSession: Identifiable {
    public var id: String { vault.instanceID }
    public let scope: ScopeContainer
    public let vault: PrivateVaultInteractor
}

@MainActor
public final class DaggerShowcaseCoordinator: ObservableObject {
    public let assembler: DaggerShowcaseAssembler

    @Published public var selectedTab: ShowcaseTab = .repositories
    @Published public var profile: GitHubUserProfile = .fsaldivarDefault
    @Published public var repositories: [GitHubRepoItem] = []
    @Published public var chapters: [ManifestoChapter] = []
    @Published public var selectedChapterID: String = "gigantes"
    @Published public var searchText: String = ""
    @Published public var isLoading: Bool = false

    // Estado del Grafo reflejado en la UI
    @Published public var isAuthenticated: Bool = false
    @Published public var currentSession: ValidatedSession?
    @Published public var isBentoV2Enabled: Bool = true
    @Published public var currentStrategy: any RepoExplorerStrategyProtocol

    // Scopes de módulos activos actualmente en RAM
    @Published public var activeRepoSession: ActiveRepoSession?
    @Published public var activeVaultSession: ActiveVaultSession?

    // Auth Gate disparado cuando una Precondición (ValidatedSession) bloquea un Deep Link
    @Published public var showAuthGateSheet: Bool = false
    @Published public var blockedPreconditionReason: String?
    @Published public var pendingDeepLink: ShowcaseDeepLink?

    // Telemetría de memoria y bitácora del grafo
    @Published public var totalScopesCreated: Int = 1 // GlobalScope
    @Published public var totalScopesTornDown: Int = 0
    @Published public var lastLeakAuditCount: Int = 0
    @Published public var eventLogs: [ScopeEventLog] = []

    public init(assembler: DaggerShowcaseAssembler) {
        self.assembler = assembler
        self.isAuthenticated = assembler.authBox.isAuthenticated
        self.currentSession = assembler.authBox.session
        self.isBentoV2Enabled = assembler.featureFlagBox.isBentoV2Enabled

        // Resolver estrategia inicial desde el Nodo de Regla de Negocio
        if let strategy = try? assembler.rootContainer.resolve((any RepoExplorerStrategyProtocol).self) {
            self.currentStrategy = strategy
        } else {
            self.currentStrategy = BentoRepoExplorerStrategy(
                service: LiveGitHubService(),
                manifestoRepo: ManifestoRepository()
            )
        }

        // Resolver capítulos del Manifiesto desde el Singleton del Grafo
        if let manifestoRepo = try? assembler.rootContainer.resolve(ManifestoRepository.self) {
            self.chapters = manifestoRepo.fetchChapters()
        }

        appendLog(
            category: "GlobalScope",
            message: "Grafo raíz inicializado con Parameter Packs. Nodos registrados: GitHubService, ManifestoRepository, ValidatedSession (Precondition) y RepoExplorerStrategy (BusinessRule)."
        )
    }

    public var filteredRepositories: [GitHubRepoItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return repositories
        }
        let query = searchText.lowercased()
        return repositories.filter {
            $0.name.lowercased().contains(query) ||
            $0.description.lowercased().contains(query) ||
            $0.language.lowercased().contains(query)
        }
    }

    public var environmentTitle: String {
        if let service = try? assembler.rootContainer.resolve((any GitHubServiceProtocol).self) {
            return service.environmentTitle
        }
        return "DaggerSwift v2"
    }

    public func loadInitialData() async {
        guard repositories.isEmpty else { return }
        await refreshGitHubData()
    }

    public func refreshGitHubData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let service = try assembler.rootContainer.resolve((any GitHubServiceProtocol).self)
            async let fetchedProfile = service.fetchProfile(username: "fsaldivar-dev")
            async let fetchedRepos = service.fetchRepositories(username: "fsaldivar-dev")

            let (prof, repos) = try await (fetchedProfile, fetchedRepos)
            self.profile = prof
            self.repositories = repos
            appendLog(
                category: "DomainNode",
                message: "Datos de @\(prof.login) resueltos vía \(service.isFakerEnvironment ? "FakerGitHubService" : "LiveGitHubService") (\(repos.count) repositorios)."
            )
        } catch {
            appendLog(category: "Error", message: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Regla de Negocio (Feature Flag A -> B)

    public func toggleFeatureFlagBentoV2(_ enabled: Bool) {
        assembler.featureFlagBox.setBentoV2(enabled)
        self.isBentoV2Enabled = enabled

        if let resolved = try? assembler.rootContainer.resolve((any RepoExplorerStrategyProtocol).self) {
            self.currentStrategy = resolved
            appendLog(
                category: "BusinessRule",
                message: "Feature Flag actualizado -> El grafo resolvió dinámicamente `\(resolved.variant.rawValue)` sin modificar la Vista."
            )
        }
    }

    // MARK: - Precondición (Simulación de Autenticación @fsaldivar-dev)

    public func simulateLogin() {
        let session = assembler.authBox.loginAsSaldivar()
        self.isAuthenticated = true
        self.currentSession = session
        self.showAuthGateSheet = false
        self.blockedPreconditionReason = nil

        appendLog(
            category: "Precondition",
            message: "✅ Sesión autenticada como @\(session.username) (token: \(session.tokenPreview)). El nodo `ValidatedSession` ahora está disponible en el grafo."
        )

        // Si había un Deep Link bloqueado esperando la precondición, lo re-ejecutamos automáticamente
        if let pending = pendingDeepLink {
            self.pendingDeepLink = nil
            appendLog(
                category: "Coordinator",
                message: "🔄 Re-intentando automáticamente el Deep Link pendiente: \(pending.urlString)"
            )
            handleDeepLink(pending)
        }
    }

    public func simulateLogout() {
        // Si hay módulos protegidos abiertos, hacemos teardown de sus scopes
        closeActiveRepoDetail()
        closePrivateVault()

        assembler.authBox.logout()
        self.isAuthenticated = false
        self.currentSession = nil

        appendLog(
            category: "Precondition",
            message: "🔒 Sesión cerrada. El nodo `ValidatedSession` fue invalidado y los sub-scopes protegidos liberaron su RAM."
        )
    }

    // MARK: - Apertura y Teardown de Sub-Scopes de Módulos

    public func selectRepository(_ repo: GitHubRepoItem, forceProtected: Bool = false) {
        // Si había otro repo abierto, liberamos su scope primero
        closeActiveRepoDetail()

        do {
            let result = try assembler.openRepositoryScope(
                for: repo,
                requiresAuth: forceProtected || repo.isPrivateVault
            )
            totalScopesCreated += 1
            activeRepoSession = ActiveRepoSession(scope: result.scope, inspector: result.inspector)
            appendLog(
                category: "RepoDetailModule",
                message: "🟢 Sub-scope creado en RAM para `\(repo.name)` (instancia: \(result.inspector.instanceID), activos: \(result.scope.activeInstanceCount))."
            )
        } catch let error as GraphError {
            handleGraphResolutionError(
                error,
                attemptedLink: .repoDetail(name: repo.name, requiresAuth: true)
            )
        } catch {
            appendLog(category: "Error", message: error.localizedDescription, isError: true)
        }
    }

    public func closeActiveRepoDetail() {
        guard let current = activeRepoSession else { return }
        let instanceID = current.inspector.instanceID
        let repoName = current.inspector.repo.name
        activeRepoSession = nil

        // Liberamos el sub-scope en DaggerSwift v2 y auditamos fugas con WeakObjectBox
        let leaks = current.scope.teardown().count
        lastLeakAuditCount = leaks
        totalScopesTornDown += 1

        appendLog(
            category: "Teardown",
            message: "🧹 `RepoDetailModule.teardown()` ejecutado al cerrar `\(repoName)` (\(instanceID)). Instancias en scope: 0 · Fugas detectadas: \(leaks)."
        )
    }

    public func openPrivateVault() {
        closePrivateVault()

        do {
            let result = try assembler.openPrivateVaultScope()
            totalScopesCreated += 1
            activeVaultSession = ActiveVaultSession(scope: result.scope, vault: result.vault)
            appendLog(
                category: "PrivateVaultModule",
                message: "🔐 Sub-scope protegido `PrivateVaultModule` resuelto con éxito tras validar `ValidatedSession` (\(result.vault.instanceID))."
            )
        } catch let error as GraphError {
            handleGraphResolutionError(error, attemptedLink: .privateVault)
        } catch {
            appendLog(category: "Error", message: error.localizedDescription, isError: true)
        }
    }

    public func closePrivateVault() {
        guard let current = activeVaultSession else { return }
        let id = current.vault.instanceID
        activeVaultSession = nil
        let leaks = current.scope.teardown().count
        lastLeakAuditCount = leaks
        totalScopesTornDown += 1

        appendLog(
            category: "Teardown",
            message: "🧹 `PrivateVaultModule.teardown()` ejecutado (\(id)). Claves eliminadas de RAM · Fugas detectadas: \(leaks)."
        )
    }

    // MARK: - Procesamiento de Deep Links (Cold-Start & Precondition Guard)

    public func handleDeepLinkURL(_ url: URL) {
        guard let deepLink = ShowcaseDeepLink.parse(url) else {
            appendLog(
                category: "DeepLink",
                message: "⚠️ URL no reconocida: \(url.absoluteString)",
                isError: true
            )
            return
        }
        handleDeepLink(deepLink)
    }

    public func handleDeepLink(_ deepLink: ShowcaseDeepLink) {
        appendLog(
            category: "DeepLink",
            message: "🚀 Recibido Deep Link: `\(deepLink.urlString)`"
        )

        switch deepLink {
        case .repoDetail(let name, let requiresAuth):
            let targetRepo = repositories.first(where: { $0.name.lowercased() == name.lowercased() })
                ?? LiveGitHubService.curatedRepositories.first(where: { $0.name.lowercased() == name.lowercased() })
                ?? LiveGitHubService.flagshipDaggerRepo
            selectedTab = .repositories
            selectRepository(targetRepo, forceProtected: requiresAuth)

        case .privateVault:
            openPrivateVault()

        case .manifesto(let chapterID):
            selectedChapterID = chapterID
            selectedTab = .manifesto
            appendLog(
                category: "Coordinator",
                message: "📜 Navegación directa al capítulo `\(chapterID)` del Manifiesto."
            )

        case .featureFlag(let enableBentoV2):
            toggleFeatureFlagBentoV2(enableBentoV2)
            selectedTab = .repositories
        }
    }

    // MARK: - Stress Test de Memoria (Prueba de 25 Sub-Scopes en Ráfaga)

    public func runMemoryStressTest() {
        var detectedLeaks = 0
        let sampleRepo = repositories.first ?? LiveGitHubService.flagshipDaggerRepo

        for _ in 0..<25 {
            if let (scope, _) = try? assembler.openRepositoryScope(for: sampleRepo, requiresAuth: false) {
                totalScopesCreated += 1
                detectedLeaks += scope.teardown().count
                totalScopesTornDown += 1
            }
        }
        lastLeakAuditCount = detectedLeaks
        appendLog(
            category: "StressTest",
            message: "⚡ Prueba de estrés completada: 25 sub-scopes (`RepoDetailModule`) instanciados y destruidos en ráfaga. Fugas de memoria (WeakObjectBox): \(detectedLeaks)."
        )
    }

    private func handleGraphResolutionError(_ error: GraphError, attemptedLink: ShowcaseDeepLink) {
        switch error {
        case .unmetPrecondition(let type, let reason):
            self.pendingDeepLink = attemptedLink
            self.blockedPreconditionReason = "El grafo abortó la creación del módulo porque falta el nodo `\(type)`:\n\(reason)"
            self.showAuthGateSheet = true
            appendLog(
                category: "GraphGuard",
                message: "🛑 Precondición no cumplida (`\(type)`). El Grafo rechazó instanciar el módulo y el Coordinador activó el Auth Gate guardando `\(attemptedLink.urlString)`.",
                isError: true
            )
        default:
            appendLog(category: "GraphError", message: error.localizedDescription, isError: true)
        }
    }

    private func appendLog(category: String, message: String, isError: Bool = false) {
        let entry = ScopeEventLog(category: category, message: message, isError: isError)
        eventLogs.insert(entry, at: 0)
        if eventLogs.count > 60 {
            eventLogs.removeLast()
        }
    }
}
