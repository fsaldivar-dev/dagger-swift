//
//  CountryNewsViewModel.swift
//  MultiCountryNewsDemo · Presentation -> ViewModel (MVVM)
//
//  Cumple SRP y DIP (SOLID): depende únicamente de abstracciones (`CountryAuthRepositoryProtocol`,
//  `CountryNewsComposing`) inyectadas con `@Inject`. No conoce `MexicoNewsModule`, `USANewsModule`, etc.
//

import SwiftUI
import DaggerSwift

@MainActor
@Inject(scope: CountryNewsScope.self)
public final class CountryNewsPortalViewModel: ObservableObject {
    public let authRepository: any CountryAuthRepositoryProtocol
    public let composer: any CountryNewsComposing
    public let initialLocale: any CountryLocaleProviderProtocol

    @Published public var selectedCountry: SupportedCountry = .mexico
    @Published public var currentCopy: LocalizedCountryCopy = MexicoLocaleProvider().copy
    @Published public var identifierInput: String = ""
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

        let locale = composer.resolveLocale(for: country)
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
        guard let useCase = composer.resolveNewsUseCase(for: selectedCountry, auth: authRepository) else {
            isAuthenticated = false
            headlines = []
            return
        }
        isAuthenticated = true
        headlines = await useCase.execute()
    }
}
