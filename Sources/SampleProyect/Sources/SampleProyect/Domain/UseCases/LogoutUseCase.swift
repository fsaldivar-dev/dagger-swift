//
//  LogoutUseCase.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Use Case
//  Cierra la sesión activa invalidando el nodo ValidatedSession en el grafo de Dagger.
//

import Foundation

public struct LogoutUseCase: Sendable {
    private let authRepository: any AuthRepositoryProtocol

    public init(authRepository: any AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    public func execute() {
        authRepository.logout()
    }
}
