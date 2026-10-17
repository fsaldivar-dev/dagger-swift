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

@Module(includes: [ShowcaseCoreModule.self])
public enum RepoDetailModule {
    @Scoped
    public static func repoDetailInspector(
        session: ValidatedSession,
        gitHubRepository: any GitHubRepositoryProtocol
    ) -> RepoDetailInspector {
        RepoDetailInspector(session: session, gitHubRepository: gitHubRepository)
    }
}

@Inject(scope: RepoDetailModule.self)
public final class RepoDetailInspector: ScopeDisposable, Sendable {
    public let session: ValidatedSession
    public let gitHubRepository: any GitHubRepositoryProtocol

    public let instanceID = "Inspector-" + String(UUID().uuidString.prefix(4))
    @MainActor private var disposedState: Bool = false

    public var isDisposed: Bool {
        MainActor.assumeIsolated { disposedState }
    }

    public func onScopeTeardown() {
        MainActor.assumeIsolated {
            disposedState = true
        }
    }
}

public struct ActiveRepoSession: Identifiable, Sendable {
    public var id: String { inspector.instanceID }
    public let repo: GitHubRepoItem
    public let inspector: RepoDetailInspector

    public init(repo: GitHubRepoItem, inspector: RepoDetailInspector) {
        self.repo = repo
        self.inspector = inspector
    }
}
