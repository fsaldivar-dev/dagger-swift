//
//  RepoDetailScope.swift
//  Features
//
//  Capa Features · Sub-scope de Detalle de Repositorio (RepoDetailModule).
//  Observa cómo @Inject(scope:) y @Inject generan los inits automáticamente sin boilerplate.
//

import Foundation
import DaggerSwift
import AppFoundation
import Core

@Module
public enum RepoDetailModule {}

@Inject(scope: RepoDetailModule.self)
public final class RepoDetailInspector: ScopeDisposable, @unchecked Sendable {
    public let repo: GitHubRepoItem
    public let gitHubRepository: any GitHubRepositoryProtocol

    public let instanceID = "Inspector-" + String(UUID().uuidString.prefix(4))
    public private(set) var isDisposed = false

    public func onScopeTeardown() {
        isDisposed = true
    }
}

/// Exige el nodo `ValidatedSession` (@Precondition) antes de resolver `RepoDetailInspector`.
@Inject
public final class ProtectedRepoAccess {
    public let session: ValidatedSession
    public let inspector: RepoDetailInspector
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
