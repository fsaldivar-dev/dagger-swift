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

/// Contrato en tiempo de compilación que todo módulo de país debe satisfacer.
public protocol CountryNewsModuleContract: GraphModule {
    static func localeProvider() -> any CountryLocaleProviderProtocol
    static func newsRepository() -> any CountryNewsRepositoryProtocol
}
