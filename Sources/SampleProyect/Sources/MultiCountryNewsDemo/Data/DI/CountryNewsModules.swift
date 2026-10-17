//
//  CountryNewsModules.swift
//  MultiCountryNewsDemo · Data -> DI
//
//  Módulos Plug & UnPlug por País (`@Module(1.0, scope: CountryNewsScope.self)`).
//  Cada módulo tiene su propia `@Precondition` validando que la sesión activa pertenezca a ESE país.
//

import Foundation
import DaggerSwift

@Module(1.0)
public enum CountryNewsCoreModule {}

@Module(1.0)
public enum CountryAuthServiceModule {
    @Singleton
    public static func countryAuthRepository() -> any CountryAuthRepositoryProtocol {
        CountryAuthRepositoryImpl()
    }
}

@Module(1.0, scope: CountryNewsScope.self)
public enum MexicoNewsModule: CountryNewsModuleContract {
    @Precondition("Se requiere sesión activa en México (🇲🇽)")
    public static func validateSession(auth: any CountryAuthRepositoryProtocol) -> AuthenticatedCountrySession? {
        auth.session(for: .mexico)
    }

    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { MexicoLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { MexicoNewsRepository() }
}

@Module(1.0, scope: CountryNewsScope.self)
public enum USANewsModule: CountryNewsModuleContract {
    @Precondition("Active US (🇺🇸) session required")
    public static func validateSession(auth: any CountryAuthRepositoryProtocol) -> AuthenticatedCountrySession? {
        auth.session(for: .usa)
    }

    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { USALocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { USANewsRepository() }
}

@Module(1.0, scope: CountryNewsScope.self)
public enum BrazilNewsModule: CountryNewsModuleContract {
    @Precondition("Sessão ativa no Brasil (🇧🇷) necessária")
    public static func validateSession(auth: any CountryAuthRepositoryProtocol) -> AuthenticatedCountrySession? {
        auth.session(for: .brazil)
    }

    @Scoped
    public static func localeProvider() -> any CountryLocaleProviderProtocol { BrazilLocaleProvider() }

    @Scoped
    public static func newsRepository() -> any CountryNewsRepositoryProtocol { BrazilNewsRepository() }
}

@Module(1.0, scope: CountryNewsScope.self)
public enum FranceNewsModule: CountryNewsModuleContract {
    @Precondition("Session active en France (🇫🇷) requise")
    public static func validateSession(auth: any CountryAuthRepositoryProtocol) -> AuthenticatedCountrySession? {
        auth.session(for: .france)
    }

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
