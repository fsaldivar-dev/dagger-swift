//
//  CountryNewsViewModel.swift
//  MultiCountryNewsDemo · Presentation -> ViewModel (MVVM)
//

import SwiftUI
import DaggerSwift

@MainActor
public final class CountryNewsPortalViewModel: ObservableObject {
    private let rootContainer: ScopeContainer
    private let authRepository: any CountryAuthRepositoryProtocol
    private var activeCountryScope: ScopeContainer?

    @Published public var selectedCountry: SupportedCountry = .mexico
    @Published public var currentCopy: LocalizedCountryCopy
    @Published public var identifierInput: String = ""
    @Published public var headlines: [NewsArticleItem] = []
    @Published public var isAuthenticated: Bool = false

    public init(rootContainer: ScopeContainer) throws {
        self.rootContainer = rootContainer
        self.authRepository = try rootContainer.resolve((any CountryAuthRepositoryProtocol).self)

        let initialScope = rootContainer.makeChildScope(for: MexicoNewsModule.self)
        self.activeCountryScope = initialScope
        let locale = try initialScope.resolve((any CountryLocaleProviderProtocol).self)
        self.currentCopy = locale.copy
        self.identifierInput = locale.copy.defaultIdentifier
        Task { await refreshState() }
    }

    public func selectCountry(_ country: SupportedCountry) {
        selectedCountry = country
        activeCountryScope?.teardown()

        let countryModule = Self.module(for: country)
        let newScope = rootContainer.makeChildScope(for: countryModule)
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
