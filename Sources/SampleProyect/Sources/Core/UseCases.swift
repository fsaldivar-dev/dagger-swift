//
//  UseCases.swift
//  Core
//
//  Capa Core · Casos de Uso con `@Inject`.
//  Encapsulan el repositorio (`let gitHubRepository` no público) para cumplir la Ley de Demeter.
//

import Foundation
import DaggerSwift
import AppFoundation

@Inject
public struct GetProfileUseCase: Sendable {
    let gitHubRepository: any GitHubRepositoryProtocol

    public var environmentTitle: String {
        gitHubRepository.environmentTitle
    }

    public func execute(username: String = "fsaldivar-dev") async throws -> GitHubUserProfile {
        try await gitHubRepository.fetchProfile(username: username)
    }
}

@Inject
public struct GetRepositoriesUseCase: Sendable {
    let gitHubRepository: any GitHubRepositoryProtocol

    public func execute(username: String = "fsaldivar-dev") async throws -> [GitHubRepoItem] {
        try await gitHubRepository.fetchRepositories(username: username)
    }
}
