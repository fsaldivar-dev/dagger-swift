//
//  ServiceProtocols.swift
//  Core
//
//  Capa Core · Contratos de Dominio y Servicios (Inversión de Dependencias).
//  Las Features dependen únicamente de estos contratos, nunca de implementaciones de red.
//

import Foundation
import AppFoundation

public protocol GitHubRepositoryProtocol: Sendable {
    var environmentTitle: String { get }
    var isFakerEnvironment: Bool { get }
    func fetchProfile(username: String) async throws -> GitHubUserProfile
    func fetchRepositories(username: String) async throws -> [GitHubRepoItem]
}

public protocol AuthRepositoryProtocol: Sendable {
    var isAuthenticated: Bool { get }
    var currentSession: ValidatedSession? { get }
    @discardableResult func loginAsSaldivar() -> ValidatedSession
    func logout()
}

public protocol FeatureFlagRepositoryProtocol: Sendable {
    var isBentoV2Enabled: Bool { get }
    func setBentoV2(_ enabled: Bool)
}
