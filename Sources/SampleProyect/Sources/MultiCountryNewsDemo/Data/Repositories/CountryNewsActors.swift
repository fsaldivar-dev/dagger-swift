//
//  CountryNewsActors.swift
//  MultiCountryNewsDemo · Data -> Repositories
//
//  Concurrencia Swift 6: Actores nativos (`public actor`) para los repositorios de noticias
//  y aislamiento `@MainActor` para el estado de sesión (Cero `NSLock`, Cero `@unchecked Sendable`).
//

import Foundation
import DaggerSwift

@Inject
public final class CountryAuthRepositoryImpl: CountryAuthRepositoryProtocol, Sendable {
    @MainActor private var session: AuthenticatedCountrySession? = nil

    public var currentSession: AuthenticatedCountrySession? {
        MainActor.assumeIsolated { session }
    }

    @discardableResult
    public func login(identifier: String, country: SupportedCountry) -> AuthenticatedCountrySession {
        MainActor.assumeIsolated {
            let newSession = AuthenticatedCountrySession(
                country: country,
                userIdentifier: identifier,
                sessionToken: "\(country.rawValue)-JWT-" + String(UUID().uuidString.prefix(6))
            )
            self.session = newSession
            return newSession
        }
    }

    public func logout() {
        MainActor.assumeIsolated { self.session = nil }
    }
}

// MARK: - 1. 🇲🇽 México (Español)

public struct MexicoLocaleProvider: CountryLocaleProviderProtocol {
    public let copy = LocalizedCountryCopy(
        country: .mexico, languageCode: "es-MX", regionBadge: "🇲🇽 México · Español",
        loginTitle: "Bienvenido a Noticias México",
        loginSubtitle: "Inicia sesión con tu teléfono o identificador para acceder a los titulares nacionales.",
        identifierPlaceholder: "Teléfono (+52) o CURP", defaultIdentifier: "+52 55 8421 0900",
        loginButtonTitle: "Entrar", logoutButtonTitle: "Salir",
        preconditionBlockedMessage: "Inicia sesión para desbloquear tu feed de noticias.",
        newsHeaderTitle: "Titulares en México", newsHeaderSubtitle: "Edición Nacional en Español",
        breakingTag: "ÚLTIMA HORA"
    )
    public init() {}
}

public actor MexicoNewsRepository: CountryNewsRepositoryProtocol {
    public init() {}
    public func fetchTopHeadlines() async -> [NewsArticleItem] {
        [
            NewsArticleItem(
                id: "mx-1", category: "Economía Digital",
                title: "SPEI 2.0 alcanza récord histórico de transferencias en tiempo real en México",
                summary: "Los pagos digitales crecen un 48% impulsados por nuevas plataformas móviles.",
                readTime: "3 min", source: "El Economista", symbolName: "bolt.horizontal.circle.fill"
            ),
            NewsArticleItem(
                id: "mx-2", category: "Tecnología",
                title: "Equipos de ingeniería en CDMX y Guadalajara lideran adopción de Swift 6",
                summary: "La arquitectura modular y el uso de actores reducen errores de concurrencia.",
                readTime: "4 min", source: "Swift México", symbolName: "swift"
            )
        ]
    }
}

// MARK: - 2. 🇺🇸 USA (English)

public struct USALocaleProvider: CountryLocaleProviderProtocol {
    public let copy = LocalizedCountryCopy(
        country: .usa, languageCode: "en-US", regionBadge: "🇺🇸 United States · English",
        loginTitle: "Welcome to US News",
        loginSubtitle: "Sign in with your US phone number or Passkey to read today's top stories.",
        identifierPlaceholder: "Phone (+1) or Passkey", defaultIdentifier: "+1 (415) 890-4210",
        loginButtonTitle: "Sign In", logoutButtonTitle: "Sign Out",
        preconditionBlockedMessage: "Sign in to unlock your personalized news feed.",
        newsHeaderTitle: "Top Stories in the US", newsHeaderSubtitle: "National Edition in English",
        breakingTag: "BREAKING NEWS"
    )
    public init() {}
}

public actor USANewsRepository: CountryNewsRepositoryProtocol {
    public init() {}
    public func fetchTopHeadlines() async -> [NewsArticleItem] {
        [
            NewsArticleItem(
                id: "us-1", category: "Silicon Valley",
                title: "Swift 6 Actors and Compile-Time Graphs Become the Standard for iOS Teams",
                summary: "Strict concurrency and clean modular boundaries eliminate data races.",
                readTime: "3 min", source: "Bay Area Tech", symbolName: "cpu.fill"
            ),
            NewsArticleItem(
                id: "us-2", category: "Finance",
                title: "Instant Payment Rails See Record Growth Across Consumer Mobile Wallets",
                summary: "Real-time settlement volume surges as multi-region apps streamline onboarding.",
                readTime: "5 min", source: "NY Financial", symbolName: "dollarsign.circle.fill"
            )
        ]
    }
}

// MARK: - 3. 🇧🇷 Brasil (Português)

public struct BrazilLocaleProvider: CountryLocaleProviderProtocol {
    public let copy = LocalizedCountryCopy(
        country: .brazil, languageCode: "pt-BR", regionBadge: "🇧🇷 Brasil · Português",
        loginTitle: "Bem-vindo ao Notícias Brasil",
        loginSubtitle: "Entre com seu CPF ou celular (+55) para acessar as principais notícias.",
        identifierPlaceholder: "CPF ou Celular (+55)", defaultIdentifier: "+55 11 98420-1100",
        loginButtonTitle: "Entrar", logoutButtonTitle: "Sair",
        preconditionBlockedMessage: "Faça login para liberar seu feed de notícias.",
        newsHeaderTitle: "Manchetes no Brasil", newsHeaderSubtitle: "Edição Nacional em Português",
        breakingTag: "URGENTE"
    )
    public init() {}
}

public actor BrazilNewsRepository: CountryNewsRepositoryProtocol {
    public init() {}
    public func fetchTopHeadlines() async -> [NewsArticleItem] {
        [
            NewsArticleItem(
                id: "br-1", category: "Finanças Digitais",
                title: "Pix Automático transforma pagamentos recorrentes e assinaturas no Brasil",
                summary: "Plataformas móveis em São Paulo lideram integração de pagamentos instantâneos.",
                readTime: "3 min", source: "Folha Tech", symbolName: "qrcode.viewfinder"
            )
        ]
    }
}

// MARK: - 4. 🇫🇷 France (Français)

public struct FranceLocaleProvider: CountryLocaleProviderProtocol {
    public let copy = LocalizedCountryCopy(
        country: .france, languageCode: "fr-FR", regionBadge: "🇫🇷 France · Français",
        loginTitle: "Bienvenue sur Actualités France",
        loginSubtitle: "Connectez-vous avec votre numéro (+33) pour accéder aux grands titres.",
        identifierPlaceholder: "Mobile (+33) ou Identifiant", defaultIdentifier: "+33 6 42 88 19 00",
        loginButtonTitle: "Se Connecter", logoutButtonTitle: "Déconnexion",
        preconditionBlockedMessage: "Connectez-vous pour accéder au fil d'actualités.",
        newsHeaderTitle: "À la Une en France", newsHeaderSubtitle: "Édition Nationale en Français",
        breakingTag: "EN DIRECT"
    )
    public init() {}
}

public actor FranceNewsRepository: CountryNewsRepositoryProtocol {
    public init() {}
    public func fetchTopHeadlines() async -> [NewsArticleItem] {
        [
            NewsArticleItem(
                id: "fr-1", category: "Technologie",
                title: "Les applications mobiles européennes adoptent l'architecture modulaire Swift 6",
                summary: "Une séparation nette entre Domain, Data et Presentation facilite le multilingue.",
                readTime: "3 min", source: "Les Échos", symbolName: "eurosign.circle.fill"
            )
        ]
    }
}
