//
//  RepoDetailScope.swift
//  Features
//
//  Capa Features · Sub-scope de Detalle de Repositorio (RepoDetailModule).
//  Provee `RepoDetailInspector` atado al ciclo de vida de la pantalla de detalle
//  y protegido por la @Precondition `ValidatedSession`.
//

import Foundation
import DaggerSwift
import AppFoundation
import Core

@Module
public enum RepoDetailModule {
    @Scoped
    public static func repoDetailInspector(
        session: ValidatedSession,
        repo: GitHubRepoItem,
        gitHubRepository: any GitHubRepositoryProtocol
    ) -> RepoDetailInspector {
        RepoDetailInspector(session: session, repo: repo, gitHubRepository: gitHubRepository)
    }
}

@Inject(scope: RepoDetailModule.self)
public final class RepoDetailInspector: ScopeDisposable, @unchecked Sendable {
    public let session: ValidatedSession
    public let repo: GitHubRepoItem
    public let gitHubRepository: any GitHubRepositoryProtocol

    public let instanceID = "Inspector-" + String(UUID().uuidString.prefix(4))
    public private(set) var isDisposed = false

    public func onScopeTeardown() {
        isDisposed = true
    }
}

public struct ActiveRepoSession: Identifiable {
    public var id: String { inspector.instanceID }
    public let scope: ScopeContainer
    public let inspector: RepoDetailInspector

    public init(scope: ScopeContainer, inspector: RepoDetailInspector) {
        self.scope = scope
        self.inspector = inspector
    }
}
