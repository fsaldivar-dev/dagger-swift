// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import AppFoundation
import Core
import DaggerSwift
import Features
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

/// Grafo generado para la raíz [ShowcaseCoreModule, LiveGitHubModule, FakerGitHubModule]: factories directas, sin `resolve`.
@MainActor
final class DaggerGraph_ShowcaseCoreModule_FakerGitHubModule {
    init() {}

    /// Abre el scope `RepoDetailModule` (sus `@Scoped` viven mientras viva el objeto devuelto).
    func makeRepoDetailModule() -> RepoDetailModuleGraph { RepoDetailModuleGraph(parent: self) }

    private var _authRepositoryProtocol: (any AuthRepositoryProtocol)?
    func authRepositoryProtocol() throws -> any AuthRepositoryProtocol {
        if let cached = _authRepositoryProtocol { return cached }
        let value = LiveGitHubModule.authRepository()
        _authRepositoryProtocol = value
        return value
    }

    func authSessionRepository() throws -> AuthSessionRepository {
        AuthSessionRepository()
    }

    func authSessionRepositoryV2() throws -> AuthSessionRepositoryV2 {
        AuthSessionRepositoryV2()
    }

    func countryAuthRepositoryImpl() throws -> CountryAuthRepositoryImpl {
        CountryAuthRepositoryImpl()
    }

    func fakerGitHubRepository() throws -> FakerGitHubRepository {
        FakerGitHubRepository()
    }

    func featureFlagRepositoryImpl() throws -> FeatureFlagRepositoryImpl {
        FeatureFlagRepositoryImpl()
    }

    private var _featureFlagRepositoryProtocol: (any FeatureFlagRepositoryProtocol)?
    func featureFlagRepositoryProtocol() throws -> any FeatureFlagRepositoryProtocol {
        if let cached = _featureFlagRepositoryProtocol { return cached }
        let value = LiveGitHubModule.featureFlags()
        _featureFlagRepositoryProtocol = value
        return value
    }

    func feedViewModel() throws -> FeedViewModel {
        try FeedViewModel(getProfileUseCase: getProfileUseCase(), getRepositoriesUseCase: getRepositoriesUseCase(), authRepository: authRepositoryProtocol(), flagRepository: featureFlagRepositoryProtocol())
    }

    func fintechABFlagsRepositoryImpl() throws -> FintechABFlagsRepositoryImpl {
        FintechABFlagsRepositoryImpl()
    }

    func getProfileUseCase() throws -> GetProfileUseCase {
        try GetProfileUseCase(gitHubRepository: gitHubRepositoryProtocol())
    }

    func getRepositoriesUseCase() throws -> GetRepositoriesUseCase {
        try GetRepositoriesUseCase(gitHubRepository: gitHubRepositoryProtocol())
    }

    private var _gitHubRepositoryProtocol: (any GitHubRepositoryProtocol)?
    func gitHubRepositoryProtocol() throws -> any GitHubRepositoryProtocol {
        if let cached = _gitHubRepositoryProtocol { return cached }
        let value = FakerGitHubModule.gitHubRepository()
        _gitHubRepositoryProtocol = value
        return value
    }

    func liveGitHubRepository() throws -> LiveGitHubRepository {
        LiveGitHubRepository()
    }

    func repoExplorerStrategyProtocol() throws -> any RepoExplorerStrategyProtocol {
        try ShowcaseCoreModule.explorerStrategy(flags: featureFlagRepositoryProtocol())
    }

    func validatedSession() throws -> ValidatedSession {
        guard let value = try ShowcaseCoreModule.validatedSession(auth: authRepositoryProtocol()) else {
            throw GraphError.unmetPrecondition(type: String(reflecting: ValidatedSession.self), reason: "Se requiere sesión activa de @fsaldivar-dev para inspeccionar módulos protegidos")
        }
        return value
    }
}
