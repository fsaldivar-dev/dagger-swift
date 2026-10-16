//
//  ShowcaseModels.swift
//  SampleProyect
//
//  Modelos de dominio puros para el Explorador de Repositorios y Manifiesto (@fsaldivar-dev).
//  100% libres de decoradores o acoplamientos al motor de inyección.
//

import Foundation

public struct GitHubUserProfile: Codable, Sendable, Equatable {
    public let login: String
    public let name: String
    public let bio: String
    public let location: String
    public let avatarURL: String
    public let htmlURL: String
    public let publicRepos: Int
    public let followers: Int
    public let following: Int

    public init(
        login: String,
        name: String,
        bio: String,
        location: String,
        avatarURL: String,
        htmlURL: String,
        publicRepos: Int,
        followers: Int,
        following: Int
    ) {
        self.login = login
        self.name = name
        self.bio = bio
        self.location = location
        self.avatarURL = avatarURL
        self.htmlURL = htmlURL
        self.publicRepos = publicRepos
        self.followers = followers
        self.following = following
    }

    public static let fsaldivarDefault = GitHubUserProfile(
        login: "fsaldivar-dev",
        name: "Saldivar",
        bio: "Desarrollador mobile · Creador de DaggerSwift, AutoPilot & Codaru",
        location: "MX",
        avatarURL: "https://avatars.githubusercontent.com/u/16517868?v=4",
        htmlURL: "https://github.com/fsaldivar-dev",
        publicRepos: 26,
        followers: 10,
        following: 8
    )
}

public struct GitHubRepoItem: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String
    public let language: String
    public let stars: Int
    public let forks: Int
    public let openIssues: Int
    public let htmlURL: String
    public let defaultBranch: String
    public let isPrivateVault: Bool
    public let sizeKB: Int
    public let licenseName: String
    public let architectureNotes: String
    public let sampleFiles: [String]

    public init(
        id: Int,
        name: String,
        fullName: String,
        description: String,
        language: String,
        stars: Int,
        forks: Int,
        openIssues: Int,
        htmlURL: String,
        defaultBranch: String = "main",
        isPrivateVault: Bool = false,
        sizeKB: Int = 512,
        licenseName: String = "MIT",
        architectureNotes: String = "",
        sampleFiles: [String] = []
    ) {
        self.id = id
        self.name = name
        self.fullName = fullName
        self.description = description
        self.language = language
        self.stars = stars
        self.forks = forks
        self.openIssues = openIssues
        self.htmlURL = htmlURL
        self.defaultBranch = defaultBranch
        self.isPrivateVault = isPrivateVault
        self.sizeKB = sizeKB
        self.licenseName = licenseName
        self.architectureNotes = architectureNotes
        self.sampleFiles = sampleFiles
    }
}

public struct ManifestoChapter: Identifiable, Sendable, Equatable {
    public let id: String
    public let badge: String
    public let title: String
    public let subtitle: String
    public let quote: String
    public let paragraphs: [String]

    public init(
        id: String,
        badge: String,
        title: String,
        subtitle: String,
        quote: String,
        paragraphs: [String]
    ) {
        self.id = id
        self.badge = badge
        self.title = title
        self.subtitle = subtitle
        self.quote = quote
        self.paragraphs = paragraphs
    }
}

public enum ShowcaseDeepLink: Equatable, Sendable, Identifiable {
    case repoDetail(name: String, requiresAuth: Bool)
    case privateVault
    case manifesto(chapterID: String)
    case featureFlag(enableBentoV2: Bool)

    public var id: String {
        switch self {
        case .repoDetail(let name, let auth):
            return "repo-\(name)-\(auth)"
        case .privateVault:
            return "private-vault"
        case .manifesto(let chapterID):
            return "manifesto-\(chapterID)"
        case .featureFlag(let enable):
            return "flag-\(enable)"
        }
    }

    public var urlString: String {
        switch self {
        case .repoDetail(let name, let requiresAuth):
            return requiresAuth
                ? "daggerswift://repo/\(name)?protected=true"
                : "daggerswift://repo/\(name)"
        case .privateVault:
            return "daggerswift://vault/enterprise-secrets"
        case .manifesto(let chapterID):
            return "daggerswift://manifesto/\(chapterID)"
        case .featureFlag(let enableBentoV2):
            return "daggerswift://feature-flag/bento-v2?enabled=\(enableBentoV2)"
        }
    }

    public var title: String {
        switch self {
        case .repoDetail(let name, let requiresAuth):
            return requiresAuth ? "🔒 Repo Protegido: \(name)" : "📦 Repo Público: \(name)"
        case .privateVault:
            return "🔐 Bóveda Privada (@fsaldivar-dev)"
        case .manifesto(let chapterID):
            return "📜 Manifiesto: \(chapterID)"
        case .featureFlag(let enableBentoV2):
            return enableBentoV2 ? "🚩 Regla de Negocio: Activar Bento v2" : "🚩 Regla de Negocio: Volver a Clásico v1"
        }
    }

    public static func parse(_ url: URL) -> ShowcaseDeepLink? {
        guard url.scheme?.lowercased() == "daggerswift" else { return nil }
        let host = url.host?.lowercased() ?? ""
        let pathComponent = url.pathComponents.dropFirst().first ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        switch host {
        case "repo":
            let requiresAuth = queryItems.first(where: { $0.name == "protected" })?.value == "true"
            let repoName = pathComponent.isEmpty ? "dagger-swift" : pathComponent
            return .repoDetail(name: repoName, requiresAuth: requiresAuth)
        case "vault":
            return .privateVault
        case "manifesto":
            let chapter = pathComponent.isEmpty ? "gigantes" : pathComponent
            return .manifesto(chapterID: chapter)
        case "feature-flag":
            let enabled = queryItems.first(where: { $0.name == "enabled" })?.value != "false"
            return .featureFlag(enableBentoV2: enabled)
        default:
            return nil
        }
    }
}
