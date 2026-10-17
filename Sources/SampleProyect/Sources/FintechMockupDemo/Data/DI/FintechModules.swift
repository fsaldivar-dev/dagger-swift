//
//  FintechModules.swift
//  FintechMockupDemo · Data -> DI
//
//  Paleta de evolución `@Module(0.1)` -> `@Module(1.0)` -> `@Module(2.0)` + `@BusinessRule` A/B.
//

import Foundation
import DaggerSwift

@Module(1.0)
public enum FintechCoreModule {
    @BusinessRule
    public static func provideHomeLayoutVariant(
        flags: any FintechABFlagsRepositoryProtocol
    ) -> any FintechHomeLayoutVariantProtocol {
        flags.isWealthBentoVariantB ? WealthBentoLayoutVariant() : ClassicBalanceLayoutVariant()
    }

    @BusinessRule
    public static func provideCreditOfferVariant(
        flags: any FintechABFlagsRepositoryProtocol
    ) -> any FintechCreditOfferVariantProtocol {
        flags.isInstantCreditBoostVariantB ? InstantBoostCreditOfferVariant() : StandardCreditOfferVariant()
    }
}

@Module(1.0)
public enum FintechSharedFlagsModule {
    @Singleton
    public static func abFlagsRepository() -> any FintechABFlagsRepositoryProtocol {
        FintechABFlagsRepositoryImpl()
    }
}

@Module(0.1, scope: FintechScope.self, includes: [FintechCoreModule.self, FintechSharedFlagsModule.self])
public enum FintechModuleV0_1 {
    @Scoped
    public static func coreBanking() -> any FintechCoreBankingProtocol {
        FintechCoreBankingImpl()
    }

    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV0_1()
    }
}

@Module(1.0, scope: FintechScope.self, includes: [FintechModuleV0_1.self])
public enum FintechModuleV1 {
    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV1()
    }
}

@Module(2.0, scope: FintechScope.self, includes: [FintechModuleV1.self])
public enum FintechModuleV2 {
    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV2()
    }
}
