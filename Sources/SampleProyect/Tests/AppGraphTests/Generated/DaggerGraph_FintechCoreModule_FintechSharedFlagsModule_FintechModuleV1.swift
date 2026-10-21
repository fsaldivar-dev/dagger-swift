// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

/// Grafo generado para la raíz [FintechCoreModule, FintechSharedFlagsModule, FintechModuleV0_1, FintechModuleV1]: factories directas, sin `resolve`.
@MainActor
final class DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV1 {
    init() {}

    /// Abre el scope `FintechScope` (sus `@Scoped` viven mientras viva el objeto devuelto).
    func makeFintechScope() -> FintechScopeGraph { FintechScopeGraph(parent: self) }

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

    private var _fintechABFlagsRepositoryProtocol: (any FintechABFlagsRepositoryProtocol)?
    func fintechABFlagsRepositoryProtocol() -> any FintechABFlagsRepositoryProtocol {
        if let cached = _fintechABFlagsRepositoryProtocol { return cached }
        let value = FintechSharedFlagsModule.abFlagsRepository()
        _fintechABFlagsRepositoryProtocol = value
        return value
    }

    func fintechCreditOfferVariantProtocol() -> any FintechCreditOfferVariantProtocol {
        FintechCoreModule.provideCreditOfferVariant(flags: fintechABFlagsRepositoryProtocol())
    }

    func fintechHomeLayoutVariantProtocol() -> any FintechHomeLayoutVariantProtocol {
        FintechCoreModule.provideHomeLayoutVariant(flags: fintechABFlagsRepositoryProtocol())
    }

    func liveGitHubRepository() -> LiveGitHubRepository {
        LiveGitHubRepository()
    }
}
