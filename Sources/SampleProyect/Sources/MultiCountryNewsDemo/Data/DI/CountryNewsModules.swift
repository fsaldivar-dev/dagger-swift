//
//  CountryNewsModules.swift
//  MultiCountryNewsDemo · Data -> DI
//
//  Módulos Plug & UnPlug por País (`@Module(1.0, scope: CountryNewsScope.self)`).
//

import Foundation
import DaggerSwift

@Module(1.0)
public enum CountryNewsCoreModule {
    @Precondition("Inicia sesión para acceder a las noticias del país seleccionado")
    public static func validateCountrySession(
        auth: any CountryAuthRepositoryProtocol
    ) -> AuthenticatedCountrySession? {
        auth.currentSession
    }
}

@Module(1.0)
public enum CountryAuthServiceModule {
    @Singleton
    public static func countryAuthRepository() -> any CountryAuthRepositoryProtocol {
        CountryAuthRepositoryImpl()
    }
}

@Module(1.0, scope: CountryNewsScope.self)
public enum MexicoNewsModule: CountryNewsModuleContract {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { MexicoLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { MexicoNewsRepository() }
}

@Module(1.0, scope: CountryNewsScope.self)
public enum USANewsModule: CountryNewsModuleContract {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { USALocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { USANewsRepository() }
}

@Module(1.0, scope: CountryNewsScope.self)
public enum BrazilNewsModule: CountryNewsModuleContract {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { BrazilLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { BrazilNewsRepository() }
}

@Module(1.0, scope: CountryNewsScope.self)
public enum FranceNewsModule: CountryNewsModuleContract {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { FranceLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { FranceNewsRepository() }
}

public extension CountryNewsScope {
    /// Plug & UnPlug: Selecciona el `@Module` hermano correspondiente al país.
    static func module(for country: SupportedCountry) -> any CountryNewsModuleContract.Type {
        switch country {
        case .mexico: return MexicoNewsModule.self
        case .usa: return USANewsModule.self
        case .brazil: return BrazilNewsModule.self
        case .france: return FranceNewsModule.self
        }
    }
}
