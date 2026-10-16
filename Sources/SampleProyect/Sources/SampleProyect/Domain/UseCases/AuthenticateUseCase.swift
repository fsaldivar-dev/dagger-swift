//
//  AuthenticateUseCase.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Use Case
//  Autentica la sesión del arquitecto (@fsaldivar-dev) para generar el nodo ValidatedSession.
//

import Foundation

public struct AuthenticateUseCase: Sendable {
    private let authRepository: any AuthRepositoryProtocol

    public init(authRepository: any AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    @discardableResult
    public func execute() -> ValidatedSession {
        authRepository.loginAsSaldivar()
    }
}
