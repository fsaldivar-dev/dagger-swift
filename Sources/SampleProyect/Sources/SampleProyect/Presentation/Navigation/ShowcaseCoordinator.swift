//
//  ShowcaseCoordinator.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Navigation Coordinator
//  Separa navegación y presentación del ensamblaje del grafo:
//  - DaggerShowcaseAssembler: SOLO resuelve el grafo y valida precondiciones.
//  - ShowcaseCoordinator: Atrapa GraphError.unmetPrecondition y decide qué pantalla/modal presentar.
//

import Foundation
import SwiftUI
import DaggerSwift

public struct ActiveRepoSession: Identifiable {
    public var id: String { inspector.instanceID }
    public let scope: ScopeContainer
    public let inspector: RepoDetailInspector

    public init(scope: ScopeContainer, inspector: RepoDetailInspector) {
        self.scope = scope
        self.inspector = inspector
    }
}

public struct ActiveVaultSession: Identifiable {
    public var id: String { vault.instanceID }
    public let scope: ScopeContainer
    public let vault: PrivateVaultInteractor

    public init(scope: ScopeContainer, vault: PrivateVaultInteractor) {
        self.scope = scope
        self.vault = vault
    }
}

@MainActor
public final class ShowcaseCoordinator: ObservableObject {
    public let assembler: DaggerShowcaseAssembler

    @Published public var selectedTab: ShowcaseTab = .repositories

    // Navegación modular por Sheets
    @Published public var activeRepoSession: ActiveRepoSession?
    @Published public var activeVaultSession: ActiveVaultSession?

    // Auth Precondition Gate
    @Published public var showAuthGateSheet: Bool = false
    @Published public var blockedPreconditionReason: String?
    @Published public var pendingDeepLink: ShowcaseDeepLink?

    // Métricas del DAG y Auditoría de Fugas (WeakObjectBox)
    @Published public var totalScopesCreated: Int = 1
    @Published public var totalScopesTornDown: Int = 0
    @Published public var lastLeakAuditCount: Int = 0
    @Published public var eventLogs: [ScopeEventLog] = []

    public init(assembler: DaggerShowcaseAssembler) {
        self.assembler = assembler
        appendLog(
            category: "GlobalScope",
            message: "Grafo raíz Clean Architecture inicializado con Parameter Packs (Swift 6). Nodos listos: GitHubRepository, ManifestoRepository, ValidatedSession y UseCases."
        )
    }

    // MARK: - Manejo de Scopes de Detalle de Repositorio

    public func openRepository(_ repo: GitHubRepoItem, forceProtected: Bool = false) {
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
                message: "🟢 Sub-scope creado en RAM para `\(repo.name)` (\(result.inspector.instanceID), vivos: \(result.scope.activeInstanceCount))."
            )
        } catch let error as GraphError {
            handleGraphError(error, attemptedLink: .repoDetail(name: repo.name, requiresAuth: true))
        } catch {
            appendLog(category: "Error", message: error.localizedDescription, isError: true)
        }
    }

    public func closeActiveRepoDetail() {
        guard let current = activeRepoSession else { return }
        let id = current.inspector.instanceID
        let name = current.inspector.repo.name
        activeRepoSession = nil

        let leaks = current.scope.teardown().count
        lastLeakAuditCount = leaks
        totalScopesTornDown += 1
        appendLog(
            category: "Teardown",
            message: "🧹 `RepoDetailModule.teardown()` ejecutado para `\(name)` (\(id)). Fugas detectadas: \(leaks)."
        )
    }

    // MARK: - Manejo de Scope de Bóveda Privada

    public func openPrivateVault() {
        closePrivateVault()
        do {
            let result = try assembler.openPrivateVaultScope()
            totalScopesCreated += 1
            activeVaultSession = ActiveVaultSession(scope: result.scope, vault: result.vault)
            appendLog(
                category: "PrivateVaultModule",
                message: "🔐 Bóveda privada resuelta exitosamente tras verificar `ValidatedSession` (\(result.vault.instanceID))."
            )
        } catch let error as GraphError {
            handleGraphError(error, attemptedLink: .privateVault)
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
            message: "🧹 `PrivateVaultModule.teardown()` ejecutado (\(id)). Claves eliminadas de RAM · Fugas: \(leaks)."
        )
    }

    // MARK: - Manejo de Deep Links

    public func handleDeepLinkURL(_ url: URL) {
        guard let deepLink = ShowcaseDeepLink.parse(url) else {
            appendLog(category: "DeepLink", message: "⚠️ URL no reconocida: \(url.absoluteString)", isError: true)
            return
        }
        handleDeepLink(deepLink)
    }

    public func handleDeepLink(_ deepLink: ShowcaseDeepLink) {
        appendLog(category: "DeepLink", message: "🚀 Procesando Deep Link: `\(deepLink.urlString)`")

        switch deepLink {
        case .repoDetail(let name, let requiresAuth):
            selectedTab = .repositories
            let sampleRepo = GitHubRepoItem(
                id: 12345,
                name: name,
                fullName: "fsaldivar-dev/\(name)",
                description: "Repositorio resuelto dinámicamente vía Deep Link",
                language: "Swift",
                stars: 10,
                forks: 1,
                openIssues: 0,
                htmlURL: "https://github.com/fsaldivar-dev/\(name)",
                isPrivateVault: requiresAuth
            )
            openRepository(sampleRepo, forceProtected: requiresAuth)

        case .privateVault:
            openPrivateVault()

        case .manifesto:
            selectedTab = .manifesto

        case .featureFlag(let enableBentoV2):
            if let useCase = try? assembler.rootContainer.resolve(ToggleExplorerVariantUseCase.self) {
                useCase.execute(enableBentoV2: enableBentoV2)
            }
            selectedTab = .repositories
        }
    }

    public func onAuthenticatedSuccess() {
        showAuthGateSheet = false
        blockedPreconditionReason = nil
        if let pending = pendingDeepLink {
            self.pendingDeepLink = nil
            appendLog(category: "Coordinator", message: "🔄 Reintentando Deep Link pendiente: \(pending.urlString)")
            handleDeepLink(pending)
        }
    }

    // MARK: - Telemetría y Errores del Grafo

    private func handleGraphError(_ error: GraphError, attemptedLink: ShowcaseDeepLink) {
        switch error {
        case .unmetPrecondition(let type, let reason):
            self.pendingDeepLink = attemptedLink
            self.blockedPreconditionReason = "El grafo abortó la creación del módulo en memoria porque falta el nodo `\(type)`:\n\(reason)"
            self.showAuthGateSheet = true
            appendLog(
                category: "GraphGuard",
                message: "🛑 Precondición no cumplida (`\(type)`). El grafo rechazó la instanciación. Coordinador abrió Auth Gate.",
                isError: true
            )
        default:
            appendLog(category: "GraphError", message: error.localizedDescription, isError: true)
        }
    }

    public func appendLog(category: String, message: String, isError: Bool = false) {
        let entry = ScopeEventLog(category: category, message: message, isError: isError)
        eventLogs.insert(entry, at: 0)
        if eventLogs.count > 60 {
            eventLogs.removeLast()
        }
    }
}

// Retro-compatibilidad
public typealias DaggerShowcaseCoordinator = ShowcaseCoordinator
