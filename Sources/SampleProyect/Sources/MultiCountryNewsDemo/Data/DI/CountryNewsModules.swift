//
//  CountryNewsModules.swift
//  MultiCountryNewsDemo · Data -> DI
//
//  Módulos de Inyección por País usando la paleta `@Module(1.0, scope: CountryNewsScope.self)`
//  y el contrato estático `CountryNewsModuleContract` verificado en tiempo de compilación.
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
