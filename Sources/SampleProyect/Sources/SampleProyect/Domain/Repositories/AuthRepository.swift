//
//  AuthRepository.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Repository Protocol
//  Define el contrato de autenticación y gestión de sesión activa.
//

import Foundation

public protocol AuthRepositoryProtocol: Sendable {
    var isAuthenticated: Bool { get }
    var currentSession: ValidatedSession? { get }
    @discardableResult
    func loginAsSaldivar() -> ValidatedSession
    func logout()
}
