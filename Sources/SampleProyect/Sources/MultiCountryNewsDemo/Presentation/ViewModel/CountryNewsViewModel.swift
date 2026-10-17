//
//  CountryNewsViewModel.swift
//  MultiCountryNewsDemo · Presentation -> ViewModel (MVVM)
//
//  Plug & UnPlug + Clean Architecture:
//  - Recibe únicamente `CountryAuthRepositoryProtocol` por `@Inject`.
//  - Al cambiar de país, desconecta (`teardownScope()`) el módulo anterior y conecta (`plug`) el nuevo
//    usando `CountryNewsScope.module(for:)`.
//

import SwiftUI
import DaggerSwift

@MainActor
@Inject(scope: CountryNewsScope.self)
public final class CountryNewsPortalViewModel: ObservableObject {
    public let authRepository: any CountryAuthRepositoryProtocol

    @Published public var selectedCountry: SupportedCountry = .mexico
    @Published public var currentCopy: LocalizedCountryCopy = .empty
    @Published public var identifierInput: String = ""
    @Published public var headlines: [NewsArticleItem] = []
    @Published public var isAuthenticated: Bool = false

    public func loadInitialCountry() async {
        plug(country: selectedCountry)
        await refreshState()
    }

    /// Plug & UnPlug: Desconecta el scope del país anterior y conecta el `@Module` del nuevo país.
    public func selectCountry(_ country: SupportedCountry) {
        let previousModule = CountryNewsScope.module(for: selectedCountry)
        previousModule.teardownScope()

        selectedCountry = country
        plug(country: country)

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

    private func plug(country: SupportedCountry) {
        let activeModule = CountryNewsScope.module(for: country)
        let copy = activeModule.localeProvider().copy
        currentCopy = copy
        identifierInput = copy.defaultIdentifier
    }

    private func refreshState() async {
        guard let session = CountryNewsCoreModule.validateCountrySession(auth: authRepository) else {
            isAuthenticated = false
            headlines = []
            return
        }
        let activeModule = CountryNewsScope.module(for: selectedCountry)
        let useCase = activeModule.makeNewsUseCase(session: session)
        isAuthenticated = true
        headlines = await useCase.execute()
    }
}
