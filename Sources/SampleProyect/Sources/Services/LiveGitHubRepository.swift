//
//  LiveGitHubRepository.swift
//  Services
//
//  Capa Services · Implementación en vivo del API REST de GitHub (@fsaldivar-dev).
//

import Foundation
import AppFoundation
import Core

import DaggerSwift

@Inject
public actor LiveGitHubRepository: GitHubRepositoryProtocol {
    public nonisolated let environmentTitle: String = "LIVE · GitHub API"
    public nonisolated let isFakerEnvironment: Bool = false

    public static var flagshipDaggerRepo: GitHubRepoItem { GitHubRepoItem.flagshipDaggerRepo }
    public static var curatedRepositories: [GitHubRepoItem] { GitHubRepoItem.curatedRepositories }

    private struct GitHubAPIUserDTO: Decodable {
        let login: String
        let name: String?
        let bio: String?
        let location: String?
        let avatar_url: String
        let html_url: String
        let public_repos: Int
        let followers: Int
        let following: Int
    }

    private struct GitHubAPIRepoDTO: Decodable {
        struct LicenseDTO: Decodable {
            let spdx_id: String?
        }
        let id: Int
        let name: String
        let full_name: String
        let description: String?
        let language: String?
        let stargazers_count: Int
        let forks_count: Int
        let open_issues_count: Int
        let html_url: String
        let default_branch: String?
        let size: Int?
        let license: LicenseDTO?
    }

    public func fetchProfile(username: String) async throws -> GitHubUserProfile {
        guard let url = URL(string: "https://api.github.com/users/\(username)") else {
            return .fsaldivarDefault
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("DaggerSwift-v2-Showcase", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return .fsaldivarDefault
            }
            let dto = try JSONDecoder().decode(GitHubAPIUserDTO.self, from: data)
            return GitHubUserProfile(
                login: dto.login,
                name: dto.name ?? "Saldivar",
                bio: dto.bio ?? "Desarrollador mobile",
                location: dto.location ?? "MX",
                avatarURL: dto.avatar_url,
                htmlURL: dto.html_url,
                publicRepos: dto.public_repos,
                followers: dto.followers,
                following: dto.following
            )
        } catch {
            return .fsaldivarDefault
        }
    }

    public func fetchRepositories(username: String) async throws -> [GitHubRepoItem] {
        guard let url = URL(string: "https://api.github.com/users/\(username)/repos?sort=updated&per_page=20") else {
            return Self.curatedRepositories
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("DaggerSwift-v2-Showcase", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return Self.curatedRepositories
            }
            let dtos = try JSONDecoder().decode([GitHubAPIRepoDTO].self, from: data)
            var mapped: [GitHubRepoItem] = dtos.map { dto in
                let curated = Self.curatedRepositories.first { $0.name.lowercased() == dto.name.lowercased() }
                return GitHubRepoItem(
                    id: dto.id,
                    name: dto.name,
                    fullName: dto.full_name,
                    description: dto.description ?? curated?.description ?? "Repositorio Open Source de @fsaldivar-dev",
                    language: dto.language ?? curated?.language ?? "Swift",
                    stars: max(dto.stargazers_count, curated?.stars ?? 1),
                    forks: dto.forks_count,
                    openIssues: dto.open_issues_count,
                    htmlURL: dto.html_url,
                    defaultBranch: dto.default_branch ?? "main",
                    isPrivateVault: curated?.isPrivateVault ?? false,
                    sizeKB: dto.size ?? 1024,
                    licenseName: dto.license?.spdx_id ?? "MIT",
                    architectureNotes: curated?.architectureNotes ?? "Módulo inspeccionado con sub-scope RepoDetailModule.",
                    sampleFiles: curated?.sampleFiles ?? ["README.md", "Package.swift"]
                )
            }

            if !mapped.contains(where: { $0.name.lowercased() == "dagger-swift" }) {
                mapped.insert(Self.flagshipDaggerRepo, at: 0)
            }
            return mapped
        } catch {
            return Self.curatedRepositories
        }
    }
}
