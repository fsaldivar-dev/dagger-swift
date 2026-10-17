//
//  CountryNewsComposer.swift
//  MultiCountryNewsDemo · Composition Root (SOLID)
//
//  Responsabilidad Única (SRP + DIP): Ensambla los `@Module`s de Data con los UseCases
//  de Domain y el ViewModel de Presentation, manteniendo a la Vista y al ViewModel
//  desacoplados de los módulos concretos (`MexicoNewsModule`, `USANewsModule`, etc.).
//

import SwiftUI
import DaggerSwift

public protocol CountryNewsComposing: Sendable {
    func resolveLocale(for country: SupportedCountry) -> any CountryLocaleProviderProtocol
    func resolveNewsUseCase(for country: SupportedCountry, auth: any CountryAuthRepositoryProtocol) -> GetLocalizedNewsFeedUseCase?
}

@Inject
public struct CountryNewsComposer: CountryNewsComposing {
    public func resolveLocale(for country: SupportedCountry) -> any CountryLocaleProviderProtocol {
        Self.module(for: country).localeProvider()
    }

    public func resolveNewsUseCase(
        for country: SupportedCountry,
        auth: any CountryAuthRepositoryProtocol
    ) -> GetLocalizedNewsFeedUseCase? {
        guard let session = CountryNewsCoreModule.validateCountrySession(auth: auth) else {
            return nil
        }
        let activeModule = Self.module(for: country)
        return GetLocalizedNewsFeedUseCase(
            session: session,
            localeProvider: activeModule.localeProvider(),
            newsRepository: activeModule.newsRepository()
        )
    }

    public static func module(for country: SupportedCountry) -> any CountryNewsModuleContract.Type {
        switch country {
        case .mexico: return MexicoNewsModule.self
        case .usa: return USANewsModule.self
        case .brazil: return BrazilNewsModule.self
        case .france: return FranceNewsModule.self
        }
    }

    @MainActor
    public static func compose(
        initialCountry: SupportedCountry = .mexico,
        authRepository: any CountryAuthRepositoryProtocol = CountryAuthServiceModule.countryAuthRepository()
    ) -> CountryNewsFeatureView {
        let composer = CountryNewsComposer()
        let viewModel = CountryNewsPortalViewModel(
            authRepository: authRepository,
            composer: composer,
            initialLocale: composer.resolveLocale(for: initialCountry)
        )
        return CountryNewsFeatureView(viewModel: viewModel)
    }
}
