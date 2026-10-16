//
//  UseCases.swift
//  Core
//
//  Capa Core · Casos de Uso con @Inject.
//  Observa que NO necesitan init manual ni registrarse en ningún @Module:
//  DaggerSwift genera el init y los auto-resuelve Just-In-Time.
//

import Foundation
import DaggerSwift
import AppFoundation

@Inject
public struct GetProfileUseCase: Sendable {
    public let gitHubRepository: any GitHubRepositoryProtocol

    public func execute(username: String = "fsaldivar-dev") async throws -> GitHubUserProfile {
        try await gitHubRepository.fetchProfile(username: username)
    }
}

@Inject
public struct GetRepositoriesUseCase: Sendable {
    public let gitHubRepository: any GitHubRepositoryProtocol

    public func execute(username: String = "fsaldivar-dev") async throws -> [GitHubRepoItem] {
        try await gitHubRepository.fetchRepositories(username: username)
    }
}
