//
//  DaggerShowcaseAssembler.swift
//  SampleProyect
//
//  Clean Architecture · DI · Composition Root
//  Punto único de ensamblaje del Grafo DAG de DaggerSwift v2.
//

import Foundation
import DaggerSwift

public final class DaggerShowcaseAssembler: @unchecked Sendable {
    public let rootContainer: ScopeContainer
    public let authRepository: any AuthRepositoryProtocol
    public let featureFlagRepository: any FeatureFlagRepositoryProtocol

    // Propiedades de conveniencia y compatibilidad
    public var authBox: AuthSessionRepository {
        (authRepository as? AuthSessionRepository) ?? AuthSessionRepository()
    }

    public var featureFlagBox: FeatureFlagRepositoryImpl {
        (featureFlagRepository as? FeatureFlagRepositoryImpl) ?? FeatureFlagRepositoryImpl()
    }

    public init(
        environment: any GraphModule.Type,
        initiallyAuthenticated: Bool = false,
        initialBentoV2Flag: Bool = true
    ) {
        let root = ShowcaseCoreModule.buildGraph(including: [environment])
        self.rootContainer = root

        // Resolución lazy de nodos raíz
        let auth = try! root.resolve((any AuthRepositoryProtocol).self)
        let flags = try! root.resolve((any FeatureFlagRepositoryProtocol).self)
        self.authRepository = auth
        self.featureFlagRepository = flags

        if initiallyAuthenticated {
            auth.loginAsSaldivar()
        }
        flags.setBentoV2(initialBentoV2Flag)
    }

    /// Abre un sub-scope de ciclo de vida corto (`RepoDetailModule`).
    /// Si el repositorio es protegido, exige el nodo de precondición `ValidatedSession`.
    public func openRepositoryScope(
        for repo: GitHubRepoItem,
        requiresAuth: Bool = false
    ) throws -> (scope: ScopeContainer, inspector: RepoDetailInspector) {
        let childScope = rootContainer.makeChildScope(for: RepoDetailModule.self)
        childScope.bindInstance(repo)

        do {
            let inspector: RepoDetailInspector
            if requiresAuth || repo.isPrivateVault {
                inspector = try ProtectedRepoAccess.resolve(in: childScope).inspector
            } else {
                inspector = try RepoDetailInspector.resolve(in: childScope)
            }
            return (childScope, inspector)
        } catch {
            childScope.teardown()
            throw error
        }
    }

    /// Abre el sub-scope protegido `PrivateVaultModule`.
    /// Requiere forzosamente que `ValidatedSession` esté presente en el grafo.
    public func openPrivateVaultScope() throws -> (scope: ScopeContainer, vault: PrivateVaultInteractor) {
        let vaultScope = rootContainer.makeChildScope(for: PrivateVaultModule.self)
        do {
            let vault = try PrivateVaultInteractor.resolve(in: vaultScope)
            return (vaultScope, vault)
        } catch {
            vaultScope.teardown()
            throw error
        }
    }
}
