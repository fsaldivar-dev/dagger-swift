// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import AppFoundation
import Core
import DaggerSwift
import Features
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

extension DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV1 {
    /// Scope `FintechScope` del grafo [FintechCoreModule, FintechSharedFlagsModule, FintechModuleV0_1, FintechModuleV1].
    @MainActor
    final class FintechScopeGraph {
        let parent: DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV1
        init(parent: DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV1) { self.parent = parent }

        private var _fintechCardEngineProtocol: (any FintechCardEngineProtocol)?
        func fintechCardEngineProtocol() throws -> any FintechCardEngineProtocol {
            if let cached = _fintechCardEngineProtocol { return cached }
            let value = FintechModuleV1.cardEngine()
            _fintechCardEngineProtocol = value
            return value
        }

        private var _fintechCoreBankingProtocol: (any FintechCoreBankingProtocol)?
        func fintechCoreBankingProtocol() throws -> any FintechCoreBankingProtocol {
            if let cached = _fintechCoreBankingProtocol { return cached }
            let value = FintechModuleV0_1.coreBanking()
            _fintechCoreBankingProtocol = value
            return value
        }

        private var _fintechMockupViewModel: FintechMockupViewModel?
        func fintechMockupViewModel() throws -> FintechMockupViewModel {
            if let cached = _fintechMockupViewModel { return cached }
            let value = try FintechMockupViewModel(flagsRepository: parent.fintechABFlagsRepositoryProtocol())
            _fintechMockupViewModel = value
            return value
        }

        func getFintechDashboardUseCase() throws -> GetFintechDashboardUseCase {
            try GetFintechDashboardUseCase(coreBanking: fintechCoreBankingProtocol(), cardEngine: fintechCardEngineProtocol(), layoutVariant: parent.fintechHomeLayoutVariantProtocol(), creditOfferVariant: parent.fintechCreditOfferVariantProtocol())
        }
    }
}
