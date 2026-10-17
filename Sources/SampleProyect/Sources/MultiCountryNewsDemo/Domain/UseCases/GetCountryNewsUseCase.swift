//
//  GetCountryNewsUseCase.swift
//  MultiCountryNewsDemo · Domain -> UseCases
//

import Foundation
import DaggerSwift

/// Caso de Uso de Dominio (`@Inject(scope: CountryNewsScope.self)`):
/// Encapsula `localeProvider` y `newsRepository` (Ley de Demeter) y exige `AuthenticatedCountrySession`.
@Inject(scope: CountryNewsScope.self)
public struct GetLocalizedNewsFeedUseCase: Sendable {
    public let session: AuthenticatedCountrySession
    let localeProvider: any CountryLocaleProviderProtocol
    let newsRepository: any CountryNewsRepositoryProtocol

    public var copy: LocalizedCountryCopy { localeProvider.copy }

    public func execute() async -> [NewsArticleItem] {
        await newsRepository.fetchTopHeadlines()
    }
}
