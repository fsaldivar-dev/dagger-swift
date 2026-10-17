//
//  CountryNewsViewModel.swift
//  MultiCountryNewsDemo · Presentation -> ViewModel (MVVM)
//
//  Usa `@Inject` igual que `FeedViewModel`: cero `init` manual y cero `rootContainer.resolve` en el inicializador.
//

import SwiftUI
import DaggerSwift

@MainActor
@Inject
public final class CountryNewsPortalViewModel: ObservableObject {
    public let authRepository: any CountryAuthRepositoryProtocol
    public let container: ScopeContainer

    private var activeCountryScope: ScopeContainer?

    @Published public var selectedCountry: SupportedCountry = .mexico
    @Published public var currentCopy: LocalizedCountryCopy = MexicoLocaleProvider().copy
    @Published public var identifierInput: String = MexicoLocaleProvider().copy.defaultIdentifier
    @Published public var headlines: [NewsArticleItem] = []
    @Published public var isAuthenticated: Bool = false

    public func loadInitialCountry() async {
        if activeCountryScope == nil {
            selectCountry(selectedCountry)
        } else {
            await refreshState()
        }
    }

    public func selectCountry(_ country: SupportedCountry) {
        selectedCountry = country
        activeCountryScope?.teardown()

        let newScope = container.makeChildScope(for: Self.module(for: country))
        activeCountryScope = newScope

        if let locale = try? newScope.resolve((any CountryLocaleProviderProtocol).self) {
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
        if activeCountryScope == nil {
            activeCountryScope = container.makeChildScope(for: Self.module(for: selectedCountry))
        }
        guard let scope = activeCountryScope,
              let useCase = try? scope.resolve(GetLocalizedNewsFeedUseCase.self) else {
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
