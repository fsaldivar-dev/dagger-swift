//
//  PrivateVaultInteractor.swift
//  SampleProyect
//
//  Clean Architecture · DI / Scoped Component
//  Vive en `PrivateVaultModule` y exige `ValidatedSession` en su constructor.
//

import Foundation
import DaggerSwift

@Module
public enum PrivateVaultModule {}

@Inject(scope: PrivateVaultModule.self)
public final class PrivateVaultInteractor: ScopeDisposable, @unchecked Sendable {
    public let session: ValidatedSession
    public let gitHubRepository: any GitHubRepositoryProtocol

    public let instanceID = "Vault-" + String(UUID().uuidString.prefix(4))
    public private(set) var isDisposed = false

    public init(session: ValidatedSession, gitHubRepository: any GitHubRepositoryProtocol) {
        self.session = session
        self.gitHubRepository = gitHubRepository
    }

    public var secretKeys: [String] {
        [
            "DEMO_MODULE_SCOPE = PrivateVaultModule (Scoped)",
            "DEMO_PRECONDITION = ValidatedSession VERIFIED",
            "DEMO_SESSION_USER = @" + session.username + " (#" + session.userID + ")",
            "DEMO_ENVIRONMENT = " + gitHubRepository.environmentTitle
        ]
    }

    public func onScopeTeardown() {
        isDisposed = true
    }
}
