//
//  CountryNewsViewModel.swift
//  MultiCountryNewsDemo · Presentation -> ViewModel (MVVM)
//
//  Usa únicamente el decorador `@Inject(scope: CountryNewsScope.self)` y los `@Module`s
//  sin referenciar `ScopeContainer`.
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
        Self.module(for: selectedCountry).teardownScope()
        selectedCountry = country

        let activeModule = Self.module(for: country)
        if let locale = try? activeModule.resolve((any CountryLocaleProviderProtocol).self) {
            currentCopy = locale.copy
            identifierInput = locale.copy.defaultIdentifier
        }

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
        let activeModule = Self.module(for: selectedCountry)
        guard let useCase = try? activeModule.resolve(GetLocalizedNewsFeedUseCase.self) else {
            isAuthenticated = false
            headlines = []
            return
        }
        isAuthenticated = true
        headlines = await useCase.execute()
    }

    private static func module(for country: SupportedCountry) -> any GraphModule.Type {
        switch country {
        case .mexico: return MexicoNewsModule.self
        case .usa: return USANewsModule.self
        case .brazil: return BrazilNewsModule.self
        case .france: return FranceNewsModule.self
        }
    }
}
