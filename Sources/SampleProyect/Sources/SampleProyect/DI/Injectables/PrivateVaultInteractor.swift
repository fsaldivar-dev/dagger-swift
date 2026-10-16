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
            "DAGGER_SIGNING_KEY_V2 = sha256:9f86d081884c7d659a2feaa0c55ad015",
            "GITHUB_APP_INSTALLATION = @" + session.username + " #" + session.userID,
            "ZERO_TRUST_PRECONDITION = ValidatedSession VERIFIED",
            "ENVIRONMENT_PROVIDER = " + gitHubRepository.environmentTitle
        ]
    }

    public func onScopeTeardown() {
        isDisposed = true
    }
}
