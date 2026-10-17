//
//  CountryNewsViewModel.swift
//  MultiCountryNewsDemo · Presentation -> ViewModel (MVVM)
//
//  Plug & UnPlug + Acceso Estricto por País:
//  - Cada país valida su propia `@Precondition` (`activeModule.validateSession(auth:)`).
//  - Si inicias sesión en 🇲🇽 México y cambias a 🇺🇸 USA, USA bloquea el acceso a noticias
//    porque tu sesión pertenece a México, pidiéndote iniciar sesión en USA.
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
    @Published public var activeSessionCountry: SupportedCountry? = nil

    public func loadInitialCountry() async {
        plug(country: selectedCountry)
        await refreshState()
    }

    /// Plug & UnPlug: Desconecta el scope del país anterior y conecta el `@Module` del nuevo país.
    /// NO auto-loguea en el nuevo país: la `@Precondition` del nuevo módulo verificará si la sesión
    /// actual realmente pertenece a ese país.
    public func selectCountry(_ country: SupportedCountry) {
        let previousModule = CountryNewsScope.module(for: selectedCountry)
        previousModule.teardownScope()

        selectedCountry = country
        plug(country: country)
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
        let activeModule = CountryNewsScope.module(for: selectedCountry)
        activeModule.teardownScope()
        authRepository.logout()
        activeSessionCountry = nil
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
        activeSessionCountry = authRepository.currentSession?.country
        let activeModule = CountryNewsScope.module(for: selectedCountry)
        guard let session = activeModule.validateSession(auth: authRepository) else {
            isAuthenticated = false
            headlines = []
            return
        }
        let useCase = activeModule.makeNewsUseCase(session: session)
        isAuthenticated = true
        headlines = await useCase.execute()
    }
}
