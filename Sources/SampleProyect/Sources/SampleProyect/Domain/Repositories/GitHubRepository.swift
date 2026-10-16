//
//  GitHubRepository.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Repository Protocol
//  Define el contrato de datos para interactuar con GitHub.
//

import Foundation

public protocol GitHubRepositoryProtocol: Sendable {
    var environmentTitle: String { get }
    var isFakerEnvironment: Bool { get }
    func fetchProfile(username: String) async throws -> GitHubUserProfile
    func fetchRepositories(username: String) async throws -> [GitHubRepoItem]
}

// Retro-compatibilidad para implementaciones existentes
public typealias GitHubServiceProtocol = GitHubRepositoryProtocol
