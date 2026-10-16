//
//  FakerGitHubRepository.swift
//  SampleProyect
//
//  Clean Architecture · Data Layer · Repository Implementation (Target: DemoFaker / Sandbox)
//  Simulación determinista offline para pruebas en simuladores o sin conexión.
//

import Foundation

public final class FakerGitHubRepository: GitHubRepositoryProtocol, Sendable {
    public let environmentTitle: String = "FAKER · Simulación Offline Determinista (DemoFaker)"
    public let isFakerEnvironment: Bool = true

    public init() {}

    public func fetchProfile(username: String) async throws -> GitHubUserProfile {
        GitHubUserProfile(
            login: "fsaldivar-dev",
            name: "Saldivar (Faker Sandbox)",
            bio: "Modo Sandbox determinista inyectado por DemoFaker sin llamadas de red · Swift 6 Clean DAG",
            location: "CDMX · Sandbox",
            avatarURL: "https://avatars.githubusercontent.com/u/16517868?v=4",
            htmlURL: "https://github.com/fsaldivar-dev",
            publicRepos: 26,
            followers: 99,
            following: 12
        )
    }

    public func fetchRepositories(username: String) async throws -> [GitHubRepoItem] {
        LiveGitHubRepository.curatedRepositories.map { repo in
            GitHubRepoItem(
                id: repo.id,
                name: repo.name,
                fullName: repo.fullName,
                description: "[FAKER] " + repo.description,
                language: repo.language,
                stars: repo.stars + 100,
                forks: repo.forks + 10,
                openIssues: repo.openIssues,
                htmlURL: repo.htmlURL,
                defaultBranch: repo.defaultBranch,
                isPrivateVault: repo.isPrivateVault,
                sizeKB: repo.sizeKB,
                licenseName: repo.licenseName,
                architectureNotes: "[Nodo Mock Inyectado] " + repo.architectureNotes,
                sampleFiles: repo.sampleFiles
            )
        }
    }
}

// Retro-compatibilidad
public typealias FakerGitHubService = FakerGitHubRepository
