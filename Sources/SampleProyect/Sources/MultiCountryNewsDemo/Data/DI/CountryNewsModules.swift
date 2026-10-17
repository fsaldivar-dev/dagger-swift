//
//  CountryNewsModules.swift
//  MultiCountryNewsDemo · Data -> DI
//
//  Módulos de Inyección por País usando la paleta `@Module(1.0, scope: CountryNewsScope.self)`.
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

@Module(1.0, scope: CountryNewsScope.self, includes: [CountryNewsCoreModule.self, CountryAuthServiceModule.self])
public enum MexicoNewsModule {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { MexicoLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { MexicoNewsRepository() }
}

@Module(1.0, scope: CountryNewsScope.self, includes: [CountryNewsCoreModule.self, CountryAuthServiceModule.self])
public enum USANewsModule {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { USALocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { USANewsRepository() }
}

@Module(1.0, scope: CountryNewsScope.self, includes: [CountryNewsCoreModule.self, CountryAuthServiceModule.self])
public enum BrazilNewsModule {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { BrazilLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { BrazilNewsRepository() }
}

@Module(1.0, scope: CountryNewsScope.self, includes: [CountryNewsCoreModule.self, CountryAuthServiceModule.self])
public enum FranceNewsModule {
    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { FranceLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { FranceNewsRepository() }
}
