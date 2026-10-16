//
//  GetRepositoriesUseCase.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Use Case
//  Obtiene la lista de repositorios open source de @fsaldivar-dev.
//

import Foundation

public struct GetRepositoriesUseCase: Sendable {
    private let gitHubRepository: any GitHubRepositoryProtocol

    public init(gitHubRepository: any GitHubRepositoryProtocol) {
        self.gitHubRepository = gitHubRepository
    }

    public func execute(username: String = "fsaldivar-dev") async throws -> [GitHubRepoItem] {
        try await gitHubRepository.fetchRepositories(username: username)
    }
}
