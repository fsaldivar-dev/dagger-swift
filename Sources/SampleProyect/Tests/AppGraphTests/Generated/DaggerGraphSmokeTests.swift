// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import AppFoundation
import Core
import DaggerSwift
import Features
import FintechMockupDemo
import Foundation
import MultiCountryNewsDemo
import Services
import Testing

/// Resuelve `type` y registra un Issue solo si es un error de programación (debió detectarse al compilar).
private func smokeResolve<T>(_ container: ScopeContainer, _ type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) {
    do {
        _ = try container.resolve(type)
    } catch let error as GraphError where !error.isProgrammerError {
        // Estado (p. ej. @Precondition sin sesión): válido en un test de humo.
    } catch {
        Issue.record("\(String(reflecting: type)): \(error)", sourceLocation: sourceLocation)
    }
}

@Suite("Humo: cada raíz resuelve con el runtime (generado por dagger-graph)")
struct DaggerGraphSmokeTests {
    @Test("Humo · [ShowcaseCoreModule, LiveGitHubModule]")
    @MainActor
    func smoke_DaggerGraph_ShowcaseCoreModule_LiveGitHubModule() {
        let root = ScopeContainer.root(modules: [ShowcaseCoreModule.self, LiveGitHubModule.self])
        let repoDetailModuleBox = root.makeChildScope(for: RepoDetailModule.self)
        smokeResolve(root, (any AuthRepositoryProtocol).self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, (any FeatureFlagRepositoryProtocol).self)
        smokeResolve(root, FeedViewModel.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, GetProfileUseCase.self)
        smokeResolve(root, GetRepositoriesUseCase.self)
        smokeResolve(root, (any GitHubRepositoryProtocol).self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(root, (any RepoExplorerStrategyProtocol).self)
        smokeResolve(root, ValidatedSession.self)
        smokeResolve(repoDetailModuleBox, RepoDetailInspector.self)
    }

    @Test("Humo · [ShowcaseCoreModule, FakerGitHubModule]")
    @MainActor
    func smoke_DaggerGraph_ShowcaseCoreModule_FakerGitHubModule() {
        let root = ScopeContainer.root(modules: [ShowcaseCoreModule.self, FakerGitHubModule.self])
        let repoDetailModuleBox = root.makeChildScope(for: RepoDetailModule.self)
        smokeResolve(root, (any AuthRepositoryProtocol).self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, (any FeatureFlagRepositoryProtocol).self)
        smokeResolve(root, FeedViewModel.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, GetProfileUseCase.self)
        smokeResolve(root, GetRepositoriesUseCase.self)
        smokeResolve(root, (any GitHubRepositoryProtocol).self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(root, (any RepoExplorerStrategyProtocol).self)
        smokeResolve(root, ValidatedSession.self)
        smokeResolve(repoDetailModuleBox, RepoDetailInspector.self)
    }

    @Test("Humo · [ShowcaseCoreModule, FakerGitHubModule, RepoDetailModule]")
    @MainActor
    func smoke_DaggerGraph_ShowcaseCoreModule_FakerGitHubModule_RepoDetailModule() {
        let root = ScopeContainer.root(modules: [ShowcaseCoreModule.self, FakerGitHubModule.self, RepoDetailModule.self])
        let repoDetailModuleBox = root.makeChildScope(for: RepoDetailModule.self)
        smokeResolve(root, (any AuthRepositoryProtocol).self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, (any FeatureFlagRepositoryProtocol).self)
        smokeResolve(root, FeedViewModel.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, GetProfileUseCase.self)
        smokeResolve(root, GetRepositoriesUseCase.self)
        smokeResolve(root, (any GitHubRepositoryProtocol).self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(root, (any RepoExplorerStrategyProtocol).self)
        smokeResolve(root, ValidatedSession.self)
        smokeResolve(repoDetailModuleBox, RepoDetailInspector.self)
    }

    @Test("Humo · [ShowcaseCoreModule]")
    func smoke_DaggerGraph_ShowcaseCoreModule() {
        let root = ScopeContainer.root(modules: [ShowcaseCoreModule.self])
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, LiveGitHubRepository.self)
    }

    @Test("Humo · [CountryAuthServiceModule, MexicoNewsModule]")
    @MainActor
    func smoke_DaggerGraph_CountryAuthServiceModule_MexicoNewsModule() {
        let root = ScopeContainer.root(modules: [CountryAuthServiceModule.self, MexicoNewsModule.self])
        let countryNewsScopeBox = root.makeChildScope(for: CountryNewsScope.self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, AuthenticatedCountrySession.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, (any CountryAuthRepositoryProtocol).self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(countryNewsScopeBox, (any CountryLocaleProviderProtocol).self)
        smokeResolve(countryNewsScopeBox, CountryNewsPortalViewModel.self)
        smokeResolve(countryNewsScopeBox, (any CountryNewsRepositoryProtocol).self)
        smokeResolve(countryNewsScopeBox, GetLocalizedNewsFeedUseCase.self)
    }

    @Test("Humo · [CountryAuthServiceModule, USANewsModule]")
    @MainActor
    func smoke_DaggerGraph_CountryAuthServiceModule_USANewsModule() {
        let root = ScopeContainer.root(modules: [CountryAuthServiceModule.self, USANewsModule.self])
        let countryNewsScopeBox = root.makeChildScope(for: CountryNewsScope.self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, AuthenticatedCountrySession.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, (any CountryAuthRepositoryProtocol).self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(countryNewsScopeBox, (any CountryLocaleProviderProtocol).self)
        smokeResolve(countryNewsScopeBox, CountryNewsPortalViewModel.self)
        smokeResolve(countryNewsScopeBox, (any CountryNewsRepositoryProtocol).self)
        smokeResolve(countryNewsScopeBox, GetLocalizedNewsFeedUseCase.self)
    }

    @Test("Humo · [CountryAuthServiceModule, BrazilNewsModule]")
    @MainActor
    func smoke_DaggerGraph_CountryAuthServiceModule_BrazilNewsModule() {
        let root = ScopeContainer.root(modules: [CountryAuthServiceModule.self, BrazilNewsModule.self])
        let countryNewsScopeBox = root.makeChildScope(for: CountryNewsScope.self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, AuthenticatedCountrySession.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, (any CountryAuthRepositoryProtocol).self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(countryNewsScopeBox, (any CountryLocaleProviderProtocol).self)
        smokeResolve(countryNewsScopeBox, CountryNewsPortalViewModel.self)
        smokeResolve(countryNewsScopeBox, (any CountryNewsRepositoryProtocol).self)
        smokeResolve(countryNewsScopeBox, GetLocalizedNewsFeedUseCase.self)
    }

    @Test("Humo · [CountryAuthServiceModule, FranceNewsModule]")
    @MainActor
    func smoke_DaggerGraph_CountryAuthServiceModule_FranceNewsModule() {
        let root = ScopeContainer.root(modules: [CountryAuthServiceModule.self, FranceNewsModule.self])
        let countryNewsScopeBox = root.makeChildScope(for: CountryNewsScope.self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, AuthenticatedCountrySession.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, (any CountryAuthRepositoryProtocol).self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(countryNewsScopeBox, (any CountryLocaleProviderProtocol).self)
        smokeResolve(countryNewsScopeBox, CountryNewsPortalViewModel.self)
        smokeResolve(countryNewsScopeBox, (any CountryNewsRepositoryProtocol).self)
        smokeResolve(countryNewsScopeBox, GetLocalizedNewsFeedUseCase.self)
    }

    @Test("Humo · [FintechCoreModule, FintechSharedFlagsModule, FintechModuleV0_1]")
    @MainActor
    func smoke_DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV0_1() {
        let root = ScopeContainer.root(modules: [FintechCoreModule.self, FintechSharedFlagsModule.self, FintechModuleV0_1.self])
        let fintechScopeBox = root.makeChildScope(for: FintechScope.self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, (any FintechABFlagsRepositoryProtocol).self)
        smokeResolve(root, (any FintechCreditOfferVariantProtocol).self)
        smokeResolve(root, (any FintechHomeLayoutVariantProtocol).self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(fintechScopeBox, (any FintechCardEngineProtocol).self)
        smokeResolve(fintechScopeBox, (any FintechCoreBankingProtocol).self)
        smokeResolve(fintechScopeBox, FintechMockupViewModel.self)
        smokeResolve(fintechScopeBox, GetFintechDashboardUseCase.self)
    }

    @Test("Humo · [FintechCoreModule, FintechSharedFlagsModule, FintechModuleV1]")
    @MainActor
    func smoke_DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV1() {
        let root = ScopeContainer.root(modules: [FintechCoreModule.self, FintechSharedFlagsModule.self, FintechModuleV1.self])
        let fintechScopeBox = root.makeChildScope(for: FintechScope.self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, (any FintechABFlagsRepositoryProtocol).self)
        smokeResolve(root, (any FintechCreditOfferVariantProtocol).self)
        smokeResolve(root, (any FintechHomeLayoutVariantProtocol).self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(fintechScopeBox, (any FintechCardEngineProtocol).self)
        smokeResolve(fintechScopeBox, (any FintechCoreBankingProtocol).self)
        smokeResolve(fintechScopeBox, FintechMockupViewModel.self)
        smokeResolve(fintechScopeBox, GetFintechDashboardUseCase.self)
    }

    @Test("Humo · [FintechCoreModule, FintechSharedFlagsModule, FintechModuleV2]")
    @MainActor
    func smoke_DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV2() {
        let root = ScopeContainer.root(modules: [FintechCoreModule.self, FintechSharedFlagsModule.self, FintechModuleV2.self])
        let fintechScopeBox = root.makeChildScope(for: FintechScope.self)
        smokeResolve(root, AuthSessionRepository.self)
        smokeResolve(root, AuthSessionRepositoryV2.self)
        smokeResolve(root, CountryAuthRepositoryImpl.self)
        smokeResolve(root, FakerGitHubRepository.self)
        smokeResolve(root, FeatureFlagRepositoryImpl.self)
        smokeResolve(root, FintechABFlagsRepositoryImpl.self)
        smokeResolve(root, (any FintechABFlagsRepositoryProtocol).self)
        smokeResolve(root, (any FintechCreditOfferVariantProtocol).self)
        smokeResolve(root, (any FintechHomeLayoutVariantProtocol).self)
        smokeResolve(root, LiveGitHubRepository.self)
        smokeResolve(fintechScopeBox, (any FintechCardEngineProtocol).self)
        smokeResolve(fintechScopeBox, (any FintechCoreBankingProtocol).self)
        smokeResolve(fintechScopeBox, FintechMockupViewModel.self)
        smokeResolve(fintechScopeBox, GetFintechDashboardUseCase.self)
    }
}
