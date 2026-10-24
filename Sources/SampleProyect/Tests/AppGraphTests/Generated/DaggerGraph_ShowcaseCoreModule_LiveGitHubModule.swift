// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import AppFoundation
import Core
import DaggerSwift
import Features
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

/// Grafo generado para la raíz [ShowcaseCoreModule, LiveGitHubModule]: factories directas, sin `resolve`.
@MainActor
final class DaggerGraph_ShowcaseCoreModule_LiveGitHubModule {
    init() {}

    /// Abre el scope `RepoDetailModule` (sus `@Scoped` viven mientras viva el objeto devuelto).
    func makeRepoDetailModule() -> RepoDetailModuleGraph { RepoDetailModuleGraph(parent: self) }

    private var _authRepositoryProtocol: (any AuthRepositoryProtocol)?
    func authRepositoryProtocol() -> any AuthRepositoryProtocol {
        if let cached = _authRepositoryProtocol { return cached }
        let value = LiveGitHubModule.authRepository()
        _authRepositoryProtocol = value
        return value
    }

    func authSessionRepository() -> AuthSessionRepository {
        AuthSessionRepository()
    }

    func authSessionRepositoryV2() -> AuthSessionRepositoryV2 {
        AuthSessionRepositoryV2()
    }

    func countryAuthRepositoryImpl() -> CountryAuthRepositoryImpl {
        CountryAuthRepositoryImpl()
    }

    func fakerGitHubRepository() -> FakerGitHubRepository {
        FakerGitHubRepository()
    }

    func featureFlagRepositoryImpl() -> FeatureFlagRepositoryImpl {
        FeatureFlagRepositoryImpl()
    }

    private var _featureFlagRepositoryProtocol: (any FeatureFlagRepositoryProtocol)?
    func featureFlagRepositoryProtocol() -> any FeatureFlagRepositoryProtocol {
        if let cached = _featureFlagRepositoryProtocol { return cached }
        let value = LiveGitHubModule.featureFlags()
        _featureFlagRepositoryProtocol = value
        return value
    }

    func feedViewModel() -> FeedViewModel {
        FeedViewModel(getProfileUseCase: getProfileUseCase(), getRepositoriesUseCase: getRepositoriesUseCase(), authRepository: authRepositoryProtocol(), flagRepository: featureFlagRepositoryProtocol())
    }

    func fintechABFlagsRepositoryImpl() -> FintechABFlagsRepositoryImpl {
        FintechABFlagsRepositoryImpl()
    }

    func getProfileUseCase() -> GetProfileUseCase {
        GetProfileUseCase(gitHubRepository: gitHubRepositoryProtocol())
    }

    func getRepositoriesUseCase() -> GetRepositoriesUseCase {
        GetRepositoriesUseCase(gitHubRepository: gitHubRepositoryProtocol())
    }

    private var _gitHubRepositoryProtocol: (any GitHubRepositoryProtocol)?
    func gitHubRepositoryProtocol() -> any GitHubRepositoryProtocol {
        if let cached = _gitHubRepositoryProtocol { return cached }
        let value = LiveGitHubModule.gitHubRepository()
        _gitHubRepositoryProtocol = value
        return value
    }

    func liveGitHubRepository() -> LiveGitHubRepository {
        LiveGitHubRepository()
    }

    func repoExplorerStrategyProtocol() -> any RepoExplorerStrategyProtocol {
        ShowcaseCoreModule.explorerStrategy(flags: featureFlagRepositoryProtocol())
    }

    func validatedSession() throws -> ValidatedSession {
        guard let value = ShowcaseCoreModule.validatedSession(auth: authRepositoryProtocol()) else {
            throw GraphError.unmetPrecondition(type: String(reflecting: ValidatedSession.self), reason: "Se requiere sesión activa de @fsaldivar-dev para inspeccionar módulos protegidos")
        }
        return value
    }
}
