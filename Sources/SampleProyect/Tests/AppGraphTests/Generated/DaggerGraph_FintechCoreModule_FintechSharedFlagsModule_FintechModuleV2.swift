// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

/// Grafo generado para la raíz [FintechCoreModule, FintechSharedFlagsModule, FintechModuleV0_1, FintechModuleV1, FintechModuleV2]: factories directas, sin `resolve`.
@MainActor
final class DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV2 {
    init() {}

    /// Abre el scope `FintechScope` (sus `@Scoped` viven mientras viva el objeto devuelto).
    func makeFintechScope() -> FintechScopeGraph { FintechScopeGraph(parent: self) }

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

    private var _fintechABFlagsRepositoryProtocol: (any FintechABFlagsRepositoryProtocol)?
    func fintechABFlagsRepositoryProtocol() throws -> any FintechABFlagsRepositoryProtocol {
        if let cached = _fintechABFlagsRepositoryProtocol { return cached }
        let value = FintechSharedFlagsModule.abFlagsRepository()
        _fintechABFlagsRepositoryProtocol = value
        return value
    }

    func fintechCreditOfferVariantProtocol() throws -> any FintechCreditOfferVariantProtocol {
        try FintechCoreModule.provideCreditOfferVariant(flags: fintechABFlagsRepositoryProtocol())
    }

    func fintechHomeLayoutVariantProtocol() throws -> any FintechHomeLayoutVariantProtocol {
        try FintechCoreModule.provideHomeLayoutVariant(flags: fintechABFlagsRepositoryProtocol())
    }

    func liveGitHubRepository() throws -> LiveGitHubRepository {
        LiveGitHubRepository()
    }
}
