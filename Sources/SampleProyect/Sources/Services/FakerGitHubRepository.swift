//
//  FakerGitHubRepository.swift
//  Services
//
//  Capa Services · Implementación Sandbox Offline determinista (Target: DemoFaker & Tests).
//

import Foundation
import DaggerSwift
import AppFoundation
import Core

@Inject
public final class FakerGitHubRepository: GitHubRepositoryProtocol, Sendable {
    public let environmentTitle: String = "SANDBOX · Faker Offline"
    public let isFakerEnvironment: Bool = true

    public func fetchProfile(username: String) async throws -> GitHubUserProfile {
        .fsaldivarDefault
    }

    public func fetchRepositories(username: String) async throws -> [GitHubRepoItem] {
        GitHubRepoItem.curatedRepositories
    }
}
