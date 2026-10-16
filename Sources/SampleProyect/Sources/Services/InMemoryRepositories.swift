//
//  InMemoryRepositories.swift
//  Services
//
//  Capa Services · Implementaciones en memoria para Autenticación y Feature Flags.
//

import Foundation
import Core

public final class AuthSessionRepository: AuthRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var session: ValidatedSession?

    public init() {}

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
            tokenFingerprint: "DAGGER-SESSION-" + String(UUID().uuidString.prefix(8))
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

public final class FeatureFlagRepositoryImpl: FeatureFlagRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var bentoV2Enabled: Bool = true

    public init() {}

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
