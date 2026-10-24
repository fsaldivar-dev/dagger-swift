// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.
// swiftlint:disable all

import DaggerSwift
import FintechMockupDemo
import MultiCountryNewsDemo
import Services

extension DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV0_1 {
    /// Scope `FintechScope` del grafo [FintechCoreModule, FintechSharedFlagsModule, FintechModuleV0_1].
    @MainActor
    final class FintechScopeGraph {
        let parent: DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV0_1
        init(parent: DaggerGraph_FintechCoreModule_FintechSharedFlagsModule_FintechModuleV0_1) { self.parent = parent }

        private var _fintechCardEngineProtocol: (any FintechCardEngineProtocol)?
        func fintechCardEngineProtocol() -> any FintechCardEngineProtocol {
            if let cached = _fintechCardEngineProtocol { return cached }
            let value = FintechModuleV0_1.cardEngine()
            _fintechCardEngineProtocol = value
            return value
        }

        private var _fintechCoreBankingProtocol: (any FintechCoreBankingProtocol)?
        func fintechCoreBankingProtocol() -> any FintechCoreBankingProtocol {
            if let cached = _fintechCoreBankingProtocol { return cached }
            let value = FintechModuleV0_1.coreBanking()
            _fintechCoreBankingProtocol = value
            return value
        }

        private var _fintechMockupViewModel: FintechMockupViewModel?
        func fintechMockupViewModel() -> FintechMockupViewModel {
            if let cached = _fintechMockupViewModel { return cached }
            let value = FintechMockupViewModel(flagsRepository: parent.fintechABFlagsRepositoryProtocol())
            _fintechMockupViewModel = value
            return value
        }

        func getFintechDashboardUseCase() -> GetFintechDashboardUseCase {
            GetFintechDashboardUseCase(coreBanking: fintechCoreBankingProtocol(), cardEngine: fintechCardEngineProtocol(), layoutVariant: parent.fintechHomeLayoutVariantProtocol(), creditOfferVariant: parent.fintechCreditOfferVariantProtocol())
        }
    }
}
