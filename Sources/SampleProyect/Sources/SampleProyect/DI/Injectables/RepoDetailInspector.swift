//
//  RepoDetailInspector.swift
//  SampleProyect
//
//  Clean Architecture · DI / Scoped Component
//  Vive exclusivamente en el scope `RepoDetailModule`.
//  Recibe la entidad `GitHubRepoItem` vía `bindInstance` (Dagger `@BindsInstance`).
//

import Foundation
import DaggerSwift

@Module
public enum RepoDetailModule {}

@Inject(scope: RepoDetailModule.self)
public final class RepoDetailInspector: ScopeDisposable, @unchecked Sendable {
    public let repo: GitHubRepoItem
    public let gitHubRepository: any GitHubRepositoryProtocol

    public let instanceID = "Inspector-" + String(UUID().uuidString.prefix(4))
    public let createdAt = Date()
    public private(set) var isDisposed = false

    public var serviceEnvironment: String { gitHubRepository.environmentTitle }

    public func onScopeTeardown() {
        isDisposed = true
    }
}
