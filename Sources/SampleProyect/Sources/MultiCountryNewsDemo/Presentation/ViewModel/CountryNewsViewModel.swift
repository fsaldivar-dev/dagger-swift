//
//  CountryNewsViewModel.swift
//  MultiCountryNewsDemo · Presentation -> ViewModel (MVVM)
//
//  Resolución 100% explícita en tiempo de compilación:
//  Cero `ScopeContainer`, cero `try!`, cero `try?`.
//

import SwiftUI
import DaggerSwift

@MainActor
@Inject(scope: CountryNewsScope.self)
public final class CountryNewsPortalViewModel: ObservableObject {
    public let authRepository: any CountryAuthRepositoryProtocol
    public let initialLocale: any CountryLocaleProviderProtocol

    @Published public var selectedCountry: SupportedCountry = .mexico
    @Published public var currentCopy: LocalizedCountryCopy = MexicoLocaleProvider().copy
    @Published public var identifierInput: String = MexicoLocaleProvider().copy.defaultIdentifier
    @Published public var headlines: [NewsArticleItem] = []
    @Published public var isAuthenticated: Bool = false

    public func loadInitialCountry() async {
        currentCopy = initialLocale.copy
        if identifierInput.isEmpty {
            identifierInput = initialLocale.copy.defaultIdentifier
        }
        await refreshState()
    }

    public func selectCountry(_ country: SupportedCountry) {
        selectedCountry = country

        let activeModule = Self.module(for: country)
        let locale = activeModule.localeProvider()
        currentCopy = locale.copy
        identifierInput = locale.copy.defaultIdentifier

        if authRepository.currentSession != nil {
            authRepository.login(identifier: identifierInput, country: country)
        }
        Task { await refreshState() }
    }

    public func login() {
        let id = identifierInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? currentCopy.defaultIdentifier
            : identifierInput
        authRepository.login(identifier: id, country: selectedCountry)
        Task { await refreshState() }
    }

    public func logout() {
        authRepository.logout()
        isAuthenticated = false
        headlines = []
    }

    private func refreshState() async {
        guard let session = CountryNewsCoreModule.validateCountrySession(auth: authRepository) else {
            isAuthenticated = false
            headlines = []
            return
        }
        let activeModule = Self.module(for: selectedCountry)
        let useCase = GetLocalizedNewsFeedUseCase(
            session: session,
            localeProvider: activeModule.localeProvider(),
            newsRepository: activeModule.newsRepository()
        )
        isAuthenticated = true
        headlines = await useCase.execute()
    }

    public static func module(for country: SupportedCountry) -> any CountryNewsModuleContract.Type {
        switch country {
        case .mexico: return MexicoNewsModule.self
        case .usa: return USANewsModule.self
        case .brazil: return BrazilNewsModule.self
        case .france: return FranceNewsModule.self
        }
    }
}
