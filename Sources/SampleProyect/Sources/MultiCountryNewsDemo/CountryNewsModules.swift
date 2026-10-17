//
//  CountryNewsModules.swift
//  Services
//
//  Demo 1 · Variantes Hermanas por País (@Module(scope: CountryNewsScope.self)):
//  - MexicoNewsModule (Español · MX)
//  - USANewsModule    (English · US)
//  - BrazilNewsModule (Português · BR)
//  - FranceNewsModule (Français · FR)
//

import Foundation
import DaggerSwift
import AppFoundation

@Inject
public final class CountryAuthRepositoryImpl: CountryAuthRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var session: AuthenticatedCountrySession? = nil

    public var currentSession: AuthenticatedCountrySession? {
        lock.lock()
        defer { lock.unlock() }
        return session
    }

    @discardableResult
    public func login(identifier: String, country: SupportedCountry) -> AuthenticatedCountrySession {
        lock.lock()
        defer { lock.unlock() }
        let newSession = AuthenticatedCountrySession(
            country: country,
            userIdentifier: identifier,
            sessionToken: "\(country.rawValue)-JWT-" + String(UUID().uuidString.prefix(6))
        )
        self.session = newSession
        return newSession
    }

    public func logout() {
        lock.lock()
        defer { lock.unlock() }
        self.session = nil
    }
}

@Module
public enum CountryAuthServiceModule {
    @Singleton
    public static func countryAuthRepository() -> any CountryAuthRepositoryProtocol {
        CountryAuthRepositoryImpl()
    }
}

// MARK: - 1. 🇲🇽 México (Español)

public struct MexicoLocaleProvider: CountryLocaleProviderProtocol {
    public let copy = LocalizedCountryCopy(
        country: .mexico,
        languageCode: "es-MX",
        regionBadge: "🇲🇽 Edición México · Español",
        loginTitle: "Acceso Regional México",
        loginSubtitle: "Ingresa tu CURP o celular (+52) para desbloquear la @Precondition de noticias.",
        identifierPlaceholder: "CURP o Teléfono (+52)",
        defaultIdentifier: "+52 55 8421 0900 · SALF92",
        loginButtonTitle: "Iniciar Sesión en México",
        logoutButtonTitle: "Cerrar Sesión",
        preconditionBlockedMessage: "🔒 @Precondition bloqueada: inicia sesión para construir el sub-grafo de Noticias.",
        newsHeaderTitle: "Titulares de Hoy en México",
        newsHeaderSubtitle: "Resuelto por MexicoNewsModule en CountryNewsScope",
        breakingTag: "ÚLTIMA HORA"
    )
    public init() {}
}

public struct MexicoNewsRepository: CountryNewsRepositoryProtocol {
    public init() {}
    public func fetchTopHeadlines() -> [NewsArticleItem] {
        [
            NewsArticleItem(
                id: "mx-1",
                category: "Fintech & Pagos",
                title: "SPEI 2.0 alcanza récord histórico de transferencias en tiempo real en México",
                summary: "Los pagos digitales crecen un 48% impulsados por arquitecturas modulares en banca móvil.",
                readTime: "3 min lectura",
                source: "El Economista Tech",
                symbolName: "bolt.horizontal.circle.fill"
            ),
            NewsArticleItem(
                id: "mx-2",
                category: "Ingeniería iOS",
                title: "Equipos en CDMX y Guadalajara adoptan Swift 6 Macros para grafos de dependencias",
                summary: "La separación en capas SPM reduce tiempos de compilación y elimina fugas de memoria.",
                readTime: "4 min lectura",
                source: "Swift México",
                symbolName: "swift"
            ),
            NewsArticleItem(
                id: "mx-3",
                category: "Mercados",
                title: "Nearshoring impulsa nuevos centros de desarrollo de software en Nuevo León y Bajío",
                summary: "Inversión tecnológica supera proyecciones del trimestre con foco en IA e infraestructura.",
                readTime: "2 min lectura",
                source: "Reforma Negocios",
                symbolName: "chart.line.uptrend.xyaxis"
            )
        ]
    }
}

@Module(scope: CountryNewsScope.self)
public enum MexicoNewsModule {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { MexicoLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { MexicoNewsRepository() }
}

// MARK: - 2. 🇺🇸 USA (English)

public struct USALocaleProvider: CountryLocaleProviderProtocol {
    public let copy = LocalizedCountryCopy(
        country: .usa,
        languageCode: "en-US",
        regionBadge: "🇺🇸 US Edition · English",
        loginTitle: "US Regional Sign In",
        loginSubtitle: "Enter your US phone (+1) or Passkey ID to satisfy the @Precondition gate.",
        identifierPlaceholder: "US Phone (+1) or Passkey",
        defaultIdentifier: "+1 (415) 890-4210 · US-PASSKEY",
        loginButtonTitle: "Sign In to US Portal",
        logoutButtonTitle: "Sign Out",
        preconditionBlockedMessage: "🔒 @Precondition locked: authenticate first to resolve the News Home subgraph.",
        newsHeaderTitle: "Top US Tech & Market News",
        newsHeaderSubtitle: "Resolved by USANewsModule in CountryNewsScope",
        breakingTag: "BREAKING NEWS"
    )
    public init() {}
}

public struct USANewsRepository: CountryNewsRepositoryProtocol {
    public init() {}
    public func fetchTopHeadlines() -> [NewsArticleItem] {
        [
            NewsArticleItem(
                id: "us-1",
                category: "Silicon Valley",
                title: "Zero-Reflection Dependency Graphs Become the Standard for Large Swift 6 Codebases",
                summary: "Compile-time macros replace legacy runtime service locators across enterprise iOS apps.",
                readTime: "3 min read",
                source: "Bay Area Engineering",
                symbolName: "cpu.fill"
            ),
            NewsArticleItem(
                id: "us-2",
                category: "Wall Street",
                title: "FedNow Instant Rails See Rapid Adoption Across US Consumer Fintech Platforms",
                summary: "Real-time settlement volume surges as mobile wallets unify multi-region payment scopes.",
                readTime: "5 min read",
                source: "NY Financial Wire",
                symbolName: "dollarsign.circle.fill"
            ),
            NewsArticleItem(
                id: "us-3",
                category: "AI & Mobile",
                title: "On-Device Neural Engines Power Next-Gen Personalized Developer Feeds",
                summary: "Low-latency local inference combines with scoped memory management for zero-leak sessions.",
                readTime: "4 min read",
                source: "TechPulse US",
                symbolName: "sparkles"
            )
        ]
    }
}

@Module(scope: CountryNewsScope.self)
public enum USANewsModule {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { USALocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { USANewsRepository() }
}

// MARK: - 3. 🇧🇷 Brasil (Português)

public struct BrazilLocaleProvider: CountryLocaleProviderProtocol {
    public let copy = LocalizedCountryCopy(
        country: .brazil,
        languageCode: "pt-BR",
        regionBadge: "🇧🇷 Edição Brasil · Português",
        loginTitle: "Acesso Regional Brasil",
        loginSubtitle: "Digite seu CPF ou celular (+55) para liberar a @Precondition do portal.",
        identifierPlaceholder: "CPF ou Celular (+55)",
        defaultIdentifier: "CPF 391.820.118-09 · +55 11",
        loginButtonTitle: "Entrar no Portal Brasil",
        logoutButtonTitle: "Sair da Sessão",
        preconditionBlockedMessage: "🔒 @Precondition bloqueada: faça login para construir o sub-grafo de Notícias.",
        newsHeaderTitle: "Manchetes do Dia no Brasil",
        newsHeaderSubtitle: "Resolvido por BrazilNewsModule em CountryNewsScope",
        breakingTag: "URGENTE"
    )
    public init() {}
}

public struct BrazilNewsRepository: CountryNewsRepositoryProtocol {
    public init() {}
    public func fetchTopHeadlines() -> [NewsArticleItem] {
        [
            NewsArticleItem(
                id: "br-1",
                category: "Ecossistema Pix",
                title: "Pix Automático transforma pagamentos recorrentes e assinaturas digitais no Brasil",
                summary: "Bancos digitais em São Paulo lideram integração com arquiteturas móveis de alta escala.",
                readTime: "3 min de leitura",
                source: "Folha Tech",
                symbolName: "qrcode.viewfinder"
            ),
            NewsArticleItem(
                id: "br-2",
                category: "Engenharia Mobile",
                title: "Super-Apps brasileiros adotam módulos isolados em Swift para escalar múltiplos países",
                summary: "Variantes irmãs de @Module permitem compartilhar fluxos inteiros sem duplicar ViewModels.",
                readTime: "4 min de leitura",
                source: "DevBrasil iOS",
                symbolName: "square.stack.3d.up.fill"
            ),
            NewsArticleItem(
                id: "br-3",
                category: "Economia Verde",
                title: "Startups de energia limpa batem recorde de captação na América Latina",
                summary: "Novos fundos priorizam infraestrutura digital e eficiência energética.",
                readTime: "2 min de leitura",
                source: "Valor Digital",
                symbolName: "leaf.circle.fill"
            )
        ]
    }
}

@Module(scope: CountryNewsScope.self)
public enum BrazilNewsModule {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { BrazilLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { BrazilNewsRepository() }
}

// MARK: - 4. 🇫🇷 France (Français)

public struct FranceLocaleProvider: CountryLocaleProviderProtocol {
    public let copy = LocalizedCountryCopy(
        country: .france,
        languageCode: "fr-FR",
        regionBadge: "🇫🇷 Édition France · Français",
        loginTitle: "Connexion Régionale France",
        loginSubtitle: "Saisissez votre identifiant (+33) pour valider la @Precondition d'accès.",
        identifierPlaceholder: "Identifiant ou Mobile (+33)",
        defaultIdentifier: "+33 6 42 88 19 00 · FR-ID",
        loginButtonTitle: "Se Connecter (France)",
        logoutButtonTitle: "Déconnexion",
        preconditionBlockedMessage: "🔒 @Precondition verrouillée : connectez-vous pour résoudre le graphe d'actualités.",
        newsHeaderTitle: "À la Une en France",
        newsHeaderSubtitle: "Résolu par FranceNewsModule dans CountryNewsScope",
        breakingTag: "EN DIRECT"
    )
    public init() {}
}

public struct FranceNewsRepository: CountryNewsRepositoryProtocol {
    public init() {}
    public func fetchTopHeadlines() -> [NewsArticleItem] {
        [
            NewsArticleItem(
                id: "fr-1",
                category: "Fintech Europe",
                title: "Les virements SEPA instantanés redéfinissent la banque mobile à Paris et Lyon",
                summary: "Les néobanques européennes déploient des graphes de dépendances modulaires multi-devises.",
                readTime: "3 min de lecture",
                source: "Les Échos Tech",
                symbolName: "eurosign.circle.fill"
            ),
            NewsArticleItem(
                id: "fr-2",
                category: "Architecture iOS",
                title: "DaggerSwift v2 permet d'isoler chaque pays dans son propre Scope mémoire ARC",
                summary: "La destruction automatique du Scope libère instantanément la RAM lors du changement de pays.",
                readTime: "4 min de lecture",
                source: "Swift Paris",
                symbolName: "memorychip.fill"
            )
        ]
    }
}

@Module(scope: CountryNewsScope.self)
public enum FranceNewsModule {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { FranceLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { FranceNewsRepository() }
}
