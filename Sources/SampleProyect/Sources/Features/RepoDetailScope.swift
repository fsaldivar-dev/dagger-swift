//
//  RepoDetailScope.swift
//  Features
//
//  Capa Features · Sub-scope de Detalle de Repositorio (`RepoDetailModule`).
//  Provee `RepoDetailInspector` protegido por la `@Precondition` `ValidatedSession`.
//

import Foundation
import DaggerSwift
import AppFoundation
import Core

@Module(includes: [ShowcaseCoreModule.self])
public enum RepoDetailModule {
    @Scoped
    public static func repoDetailInspector(session: ValidatedSession) -> RepoDetailInspector {
        RepoDetailInspector(session: session)
    }
}

@Inject(scope: RepoDetailModule.self)
public final class RepoDetailInspector: ScopeDisposable, Sendable {
    public let session: ValidatedSession

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
