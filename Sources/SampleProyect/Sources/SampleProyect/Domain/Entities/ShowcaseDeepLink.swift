//
//  ShowcaseDeepLink.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Entity
//  Representa una ruta de Deep Link (`daggerswift://...`) para navegación de la app.
//

import Foundation

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
