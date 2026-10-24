// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

extension DaggerGraph_CountryAuthServiceModule_FranceNewsModule {
    /// Scope `CountryNewsScope` del grafo [CountryAuthServiceModule, FranceNewsModule].
    @MainActor
    final class CountryNewsScopeGraph {
        let parent: DaggerGraph_CountryAuthServiceModule_FranceNewsModule
        init(parent: DaggerGraph_CountryAuthServiceModule_FranceNewsModule) { self.parent = parent }

        private var _countryLocaleProviderProtocol: (any CountryLocaleProviderProtocol)?
        func countryLocaleProviderProtocol() -> any CountryLocaleProviderProtocol {
            if let cached = _countryLocaleProviderProtocol { return cached }
            let value = FranceNewsModule.localeProvider()
            _countryLocaleProviderProtocol = value
            return value
        }

        private var _countryNewsPortalViewModel: CountryNewsPortalViewModel?
        func countryNewsPortalViewModel() -> CountryNewsPortalViewModel {
            if let cached = _countryNewsPortalViewModel { return cached }
            let value = CountryNewsPortalViewModel(authRepository: parent.countryAuthRepositoryProtocol())
            _countryNewsPortalViewModel = value
            return value
        }

        private var _countryNewsRepositoryProtocol: (any CountryNewsRepositoryProtocol)?
        func countryNewsRepositoryProtocol() -> any CountryNewsRepositoryProtocol {
            if let cached = _countryNewsRepositoryProtocol { return cached }
            let value = FranceNewsModule.newsRepository()
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
