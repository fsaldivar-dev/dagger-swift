//
//  FintechModules.swift
//  FintechMockupDemo · Data -> DI
//
//  Paleta de evolución `@Module(0.1)` -> `@Module(1.0)` -> `@Module(2.0)` + `@BusinessRule` A/B.
//  Observa que `FintechModuleV1` y `FintechModuleV2` usan `includes:` y SOLO implementan
//  la función que cambió (`cardEngine()`), heredando `coreBanking()` de `FintechModuleV0_1`.
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

/// Base 0.1 (MVP): Implementa todos los nodos base del contrato (`coreBanking` + `cardEngine`).
@Module(0.1, scope: FintechScope.self)
public enum FintechModuleV0_1: FintechModuleContract {
    @Scoped
    public static func coreBanking() -> any FintechCoreBankingProtocol {
        FintechCoreBankingImpl()
    }

    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV0_1()
    }
}

public extension FintechModuleContract {
    /// Herencia por defecto del Core Bancario desde `FintechModuleV0_1` para versiones posteriores (`1.0`, `2.0`).
    static func coreBanking() -> any FintechCoreBankingProtocol {
        FintechModuleV0_1.coreBanking()
    }
}

/// Evolución 1.0: Hereda `coreBanking()` de `0.1` y SOLO implementa `cardEngine()` con `FintechCardEngineV1`.
@Module(1.0, scope: FintechScope.self, includes: [FintechModuleV0_1.self])
public enum FintechModuleV1: FintechModuleContract {
    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV1()
    }
}

/// Evolución 2.0: Hereda `coreBanking()` y SOLO implementa `cardEngine()` con `FintechCardEngineV2` (Metal).
@Module(2.0, scope: FintechScope.self, includes: [FintechModuleV1.self])
public enum FintechModuleV2: FintechModuleContract {
    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV2()
    }
}

/// Sintetiza en compile-time `FintechScope.Palette` (`ModulePalette`) y `FintechScope.module(for:)` (estilo `CodingKeys`).
@Scope(
    of: (any FintechModuleContract).self,
    v0_1: FintechModuleV0_1.self,
    v1_0: FintechModuleV1.self,
    v2_0: FintechModuleV2.self
)
extension FintechScope {}
