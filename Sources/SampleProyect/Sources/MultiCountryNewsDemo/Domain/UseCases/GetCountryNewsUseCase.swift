//
//  GetCountryNewsUseCase.swift
//  MultiCountryNewsDemo · Domain -> UseCases
//

import Foundation
import DaggerSwift

/// Caso de Uso de Dominio (`@Inject(scope: CountryNewsScope.self)`):
/// 1. Exige la `@Precondition` `AuthenticatedCountrySession`.
/// 2. Resuelve la configuración de idioma y el `actor` de noticias del país activo.
@Inject(scope: CountryNewsScope.self)
public struct GetLocalizedNewsFeedUseCase: Sendable {
    public let session: AuthenticatedCountrySession
    public let localeProvider: any CountryLocaleProviderProtocol
    public let newsRepository: any CountryNewsRepositoryProtocol

    public var copy: LocalizedCountryCopy { localeProvider.copy }

    public func execute() async -> [NewsArticleItem] {
        await newsRepository.fetchTopHeadlines()
    }
}
