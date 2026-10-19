// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import AppFoundation
import Core
import DaggerSwift
import Features
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

/// Grafo generado para la raíz [ShowcaseCoreModule]: factories directas, sin `resolve`.
final class DaggerGraph_ShowcaseCoreModule {
    init() {}

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

    func fintechABFlagsRepositoryImpl() throws -> FintechABFlagsRepositoryImpl {
        FintechABFlagsRepositoryImpl()
    }

    func liveGitHubRepository() throws -> LiveGitHubRepository {
        LiveGitHubRepository()
    }
}
