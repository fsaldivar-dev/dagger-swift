// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

extension DaggerGraph_CountryAuthServiceModule_MexicoNewsModule {
    /// Scope `CountryNewsScope` del grafo [CountryAuthServiceModule, MexicoNewsModule].
    @MainActor
    final class CountryNewsScopeGraph {
        let parent: DaggerGraph_CountryAuthServiceModule_MexicoNewsModule
        init(parent: DaggerGraph_CountryAuthServiceModule_MexicoNewsModule) { self.parent = parent }

        private var _countryLocaleProviderProtocol: (any CountryLocaleProviderProtocol)?
        func countryLocaleProviderProtocol() throws -> any CountryLocaleProviderProtocol {
            if let cached = _countryLocaleProviderProtocol { return cached }
            let value = MexicoNewsModule.localeProvider()
            _countryLocaleProviderProtocol = value
            return value
        }

        private var _countryNewsPortalViewModel: CountryNewsPortalViewModel?
        func countryNewsPortalViewModel() throws -> CountryNewsPortalViewModel {
            if let cached = _countryNewsPortalViewModel { return cached }
            let value = try CountryNewsPortalViewModel(authRepository: parent.countryAuthRepositoryProtocol())
            _countryNewsPortalViewModel = value
            return value
        }

        private var _countryNewsRepositoryProtocol: (any CountryNewsRepositoryProtocol)?
        func countryNewsRepositoryProtocol() throws -> any CountryNewsRepositoryProtocol {
            if let cached = _countryNewsRepositoryProtocol { return cached }
            let value = MexicoNewsModule.newsRepository()
            _countryNewsRepositoryProtocol = value
            return value
        }

        private var _getLocalizedNewsFeedUseCase: GetLocalizedNewsFeedUseCase?
        func getLocalizedNewsFeedUseCase() throws -> GetLocalizedNewsFeedUseCase {
            if let cached = _getLocalizedNewsFeedUseCase { return cached }
            try _pre_getLocalizedNewsFeedUseCase()
            let value = try GetLocalizedNewsFeedUseCase(session: parent.authenticatedCountrySession(), localeProvider: countryLocaleProviderProtocol(), newsRepository: countryNewsRepositoryProtocol())
            _getLocalizedNewsFeedUseCase = value
            return value
        }

        func _pre_getLocalizedNewsFeedUseCase() throws {
            if _getLocalizedNewsFeedUseCase != nil { return }
            _ = try parent.authenticatedCountrySession()
        }
    }
}
