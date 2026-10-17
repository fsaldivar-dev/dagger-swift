//
//  CountryNewsCore.swift
//  Core
//
//  Demo 1 · Capa Core para Login Multi-Country y Home de Noticias Multi-Idioma.
//  Usa `CountryNewsScope` para que las variantes hermanas (MX, US, BR, FR)
//  alimenten los mismos hijos `@Inject(scope: CountryNewsScope.self)`.
//

import Foundation
import DaggerSwift
import AppFoundation

/// Scope compartido por todos los módulos de país (México, USA, Brasil, Francia).
public enum CountryNewsScope: GraphScope {}

/// Precondición: exige que el usuario haya iniciado sesión en el país seleccionado
/// antes de poder construir la Home de Noticias (`GetLocalizedNewsFeedUseCase`).
public struct AuthenticatedCountrySession: Precondition, Sendable, Equatable {
    public let country: SupportedCountry
    public let userIdentifier: String
    public let sessionToken: String

    public init(country: SupportedCountry, userIdentifier: String, sessionToken: String) {
        self.country = country
        self.userIdentifier = userIdentifier
        self.sessionToken = sessionToken
    }
}

public protocol CountryLocaleProviderProtocol: Sendable {
    var copy: LocalizedCountryCopy { get }
}

public protocol CountryNewsRepositoryProtocol: Sendable {
    func fetchTopHeadlines() -> [NewsArticleItem]
}

public protocol CountryAuthRepositoryProtocol: Sendable {
    var currentSession: AuthenticatedCountrySession? { get }
    @discardableResult
    func login(identifier: String, country: SupportedCountry) -> AuthenticatedCountrySession
    func logout()
}

@Module
public enum CountryNewsCoreModule {
    @Precondition("Se requiere iniciar sesión en el país seleccionado (@Precondition AuthenticatedCountrySession)")
    public static func validateCountrySession(
        auth: any CountryAuthRepositoryProtocol
    ) -> AuthenticatedCountrySession? {
        auth.currentSession
    }
}

/// Caso de Uso Hijo con `@Inject(scope: CountryNewsScope.self)`:
/// 1. Exige la `@Precondition` `AuthenticatedCountrySession`.
/// 2. Resuelve automáticamente el idioma y las noticias del país activo (MX, US, BR o FR).
@Inject(scope: CountryNewsScope.self)
public struct GetLocalizedNewsFeedUseCase: Sendable {
    public let session: AuthenticatedCountrySession
    public let localeProvider: any CountryLocaleProviderProtocol
    public let newsRepository: any CountryNewsRepositoryProtocol

    public var copy: LocalizedCountryCopy { localeProvider.copy }
    public var headlines: [NewsArticleItem] { newsRepository.fetchTopHeadlines() }
}
