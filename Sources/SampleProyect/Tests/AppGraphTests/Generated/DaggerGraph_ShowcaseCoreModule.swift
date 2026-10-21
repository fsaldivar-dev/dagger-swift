// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import FintechMockupDemo
import Foundation
import MultiCountryNewsDemo
import Services

/// Grafo generado para la raíz [ShowcaseCoreModule]: factories directas, sin `resolve`.
final class DaggerGraph_ShowcaseCoreModule: @unchecked Sendable {
    let lock = NSRecursiveLock()
    init() {}

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

    func fintechABFlagsRepositoryImpl() -> FintechABFlagsRepositoryImpl {
        FintechABFlagsRepositoryImpl()
    }

    func liveGitHubRepository() -> LiveGitHubRepository {
        LiveGitHubRepository()
    }
}
