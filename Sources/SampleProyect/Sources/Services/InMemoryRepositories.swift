//
//  InMemoryRepositories.swift
//  Services
//
//  Capa Data/Services · Implementaciones de Autenticación (v1 y v2) y Feature Flags.
//  Usa aislamiento `@MainActor` de Swift 6 (Cero `NSLock`, Cero `@unchecked Sendable`).
//

import Foundation
import DaggerSwift
import Core

@Inject
public final class AuthSessionRepository: AuthRepositoryProtocol, Sendable {
    @MainActor private var session: ValidatedSession? = nil

    public var isAuthenticated: Bool {
        MainActor.assumeIsolated { session != nil }
    }

    public var currentSession: ValidatedSession? {
        MainActor.assumeIsolated { session }
    }

    @discardableResult
    public func loginAsSaldivar() -> ValidatedSession {
        MainActor.assumeIsolated {
            let newSession = ValidatedSession(
                username: "fsaldivar-dev",
                tokenFingerprint: "DAGGER-V1-" + String(UUID().uuidString.prefix(8))
            )
            self.session = newSession
            return newSession
        }
    }

    public func logout() {
        MainActor.assumeIsolated {
            self.session = nil
        }
    }
}

/// Flujo evolucionado de Login v2 (usado por `LiveGitHubModuleV2`).
@Inject
public final class AuthSessionRepositoryV2: AuthRepositoryProtocol, Sendable {
    @MainActor private var session: ValidatedSession? = nil

    public var isAuthenticated: Bool {
        MainActor.assumeIsolated { session != nil }
    }

    public var currentSession: ValidatedSession? {
        MainActor.assumeIsolated { session }
    }

    @discardableResult
    public func loginAsSaldivar() -> ValidatedSession {
        MainActor.assumeIsolated {
            let newSession = ValidatedSession(
                username: "fsaldivar-dev",
                tokenFingerprint: "OAUTH-V2-" + String(UUID().uuidString.prefix(8))
            )
            self.session = newSession
            return newSession
        }
    }

    public func logout() {
        MainActor.assumeIsolated {
            self.session = nil
        }
    }
}

@Inject
public final class FeatureFlagRepositoryImpl: FeatureFlagRepositoryProtocol, Sendable {
    @MainActor private var bentoV2Enabled: Bool = true

    public var isBentoV2Enabled: Bool {
        MainActor.assumeIsolated { bentoV2Enabled }
    }

    public func setBentoV2(_ enabled: Bool) {
        MainActor.assumeIsolated {
            bentoV2Enabled = enabled
        }
    }
}
