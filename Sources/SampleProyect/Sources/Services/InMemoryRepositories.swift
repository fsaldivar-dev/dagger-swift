//
//  InMemoryRepositories.swift
//  Services
//
//  Capa Services · Implementaciones de Autenticación (v1 y v2) y Feature Flags.
//

import Foundation
import DaggerSwift
import Core

@Inject
public final class AuthSessionRepository: AuthRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var session: ValidatedSession? = nil

    public var isAuthenticated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return session != nil
    }

    public var currentSession: ValidatedSession? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }

    @discardableResult
    public func loginAsSaldivar() -> ValidatedSession {
        lock.lock()
        defer { lock.unlock() }
        let newSession = ValidatedSession(
            username: "fsaldivar-dev",
            tokenFingerprint: "DAGGER-V1-" + String(UUID().uuidString.prefix(8))
        )
        self.session = newSession
        return newSession
    }

    public func logout() {
        lock.lock()
        defer { lock.unlock() }
        self.session = nil
    }
}

/// Flujo evolucionado de Login v2 (usado por `LiveGitHubModuleV2`).
@Inject
public final class AuthSessionRepositoryV2: AuthRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var session: ValidatedSession? = nil

    public var isAuthenticated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return session != nil
    }

    public var currentSession: ValidatedSession? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }

    @discardableResult
    public func loginAsSaldivar() -> ValidatedSession {
        lock.lock()
        defer { lock.unlock() }
        let newSession = ValidatedSession(
            username: "fsaldivar-dev",
            tokenFingerprint: "OAUTH-V2-" + String(UUID().uuidString.prefix(8))
        )
        self.session = newSession
        return newSession
    }

    public func logout() {
        lock.lock()
        defer { lock.unlock() }
        self.session = nil
    }
}

@Inject
public final class FeatureFlagRepositoryImpl: FeatureFlagRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var bentoV2Enabled: Bool = true

    public var isBentoV2Enabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return bentoV2Enabled
    }

    public func setBentoV2(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        bentoV2Enabled = enabled
    }
}
