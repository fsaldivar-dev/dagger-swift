//
//  CountryNewsRepositories.swift
//  MultiCountryNewsDemo · Domain -> Repositories
//

import Foundation
import DaggerSwift

public protocol CountryLocaleProviderProtocol: Sendable {
    var copy: LocalizedCountryCopy { get }
}

public protocol CountryNewsRepositoryProtocol: Sendable {
    func fetchTopHeadlines() async -> [NewsArticleItem]
}

public protocol CountryAuthRepositoryProtocol: Sendable {
    var currentSession: AuthenticatedCountrySession? { get }
    func session(for country: SupportedCountry) -> AuthenticatedCountrySession?
    @discardableResult
    func login(identifier: String, country: SupportedCountry) -> AuthenticatedCountrySession
    func logout()
}

public extension CountryAuthRepositoryProtocol {
    func session(for country: SupportedCountry) -> AuthenticatedCountrySession? {
        guard let current = currentSession, current.country == country else {
            return nil
        }
        return current
    }
}

/// Contrato en tiempo de compilación que todo `@Module` de país satisface (Plug & UnPlug).
/// Incluye su propia `@Precondition` por país: iniciar sesión en México NO desbloquea USA, Brasil ni Francia.
public protocol CountryNewsModuleContract: GraphModule {
    static func validateSession(auth: any CountryAuthRepositoryProtocol) -> AuthenticatedCountrySession?
    static func localeProvider() -> any CountryLocaleProviderProtocol
    static func newsRepository() -> any CountryNewsRepositoryProtocol
}

public extension CountryNewsModuleContract {
    static func makeNewsUseCase(session: AuthenticatedCountrySession) -> GetLocalizedNewsFeedUseCase {
        GetLocalizedNewsFeedUseCase(
            session: session,
            localeProvider: localeProvider(),
            newsRepository: newsRepository()
        )
    }
}
