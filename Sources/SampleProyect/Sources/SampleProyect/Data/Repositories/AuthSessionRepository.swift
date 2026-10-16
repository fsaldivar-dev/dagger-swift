//
//  AuthSessionRepository.swift
//  SampleProyect
//
//  Clean Architecture · Data Layer · Repository Implementation
//  Almacén en memoria concurrente (`NSLock`) para la sesión autenticada.
//

import Foundation

public final class AuthSessionRepository: AuthRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var currentSessionValue: ValidatedSession?

    public init(initialSession: ValidatedSession? = nil) {
        self.currentSessionValue = initialSession
    }

    public var isAuthenticated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentSessionValue != nil
    }

    public var currentSession: ValidatedSession? {
        lock.lock()
        defer { lock.unlock() }
        return currentSessionValue
    }

    @discardableResult
    public func loginAsSaldivar() -> ValidatedSession {
        lock.lock()
        defer { lock.unlock() }
        let session = ValidatedSession()
        currentSessionValue = session
        return session
    }

    public func logout() {
        lock.lock()
        defer { lock.unlock() }
        currentSessionValue = nil
    }
}

// Retro-compatibilidad con código v2 previo
public typealias AuthSessionStateBox = AuthSessionRepository
extension AuthSessionRepository {
    public var session: ValidatedSession? { currentSession }
}
