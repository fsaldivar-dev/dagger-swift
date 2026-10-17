//
//  CountryNewsRepositories.swift
//  MultiCountryNewsDemo · Domain -> Repositories
//

import Foundation

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
