//
//  GetProfileUseCase.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Use Case
//  Obtiene el perfil público de GitHub de @fsaldivar-dev.
//

import Foundation

public struct GetProfileUseCase: Sendable {
    private let gitHubRepository: any GitHubRepositoryProtocol

    public init(gitHubRepository: any GitHubRepositoryProtocol) {
        self.gitHubRepository = gitHubRepository
    }

    public func execute(username: String = "fsaldivar-dev") async throws -> GitHubUserProfile {
        try await gitHubRepository.fetchProfile(username: username)
    }
}
