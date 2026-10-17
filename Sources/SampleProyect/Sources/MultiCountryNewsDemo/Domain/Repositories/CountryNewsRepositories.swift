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
    @discardableResult
    func login(identifier: String, country: SupportedCountry) -> AuthenticatedCountrySession
    func logout()
}

/// Contrato en tiempo de compilación que todo `@Module` de país satisface (Plug & UnPlug).
public protocol CountryNewsModuleContract: GraphModule {
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
