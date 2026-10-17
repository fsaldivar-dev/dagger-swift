//
//  FintechModules.swift
//  FintechMockupDemo
//
//  Demo 2 · Paleta de Evolución de Módulos (`@Module(0.1)` -> `@Module(1.0)` -> `@Module(2.0)`)
//  y repositorio reactivo de Feature Flags A/B para `@BusinessRule`.
//

import Foundation
import DaggerSwift
import AppFoundation

@Inject
public final class FintechABFlagsRepositoryImpl: FintechABFlagsRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var wealthBentoB: Bool = true
    private var creditBoostB: Bool = true

    public var isWealthBentoVariantB: Bool {
        lock.lock()
        defer { lock.unlock() }
        return wealthBentoB
    }

    public var isInstantCreditBoostVariantB: Bool {
        lock.lock()
        defer { lock.unlock() }
        return creditBoostB
    }

    public func setWealthBentoVariantB(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        wealthBentoB = enabled
    }

    public func setInstantCreditBoostVariantB(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        creditBoostB = enabled
    }
}

public struct FintechCoreBankingImpl: FintechCoreBankingProtocol {
    public init() {}

    public func fetchAccountSummary() -> FintechAccountSummary {
        FintechAccountSummary(
            holderName: "Fernando Saldivar",
            accountNumberMasked: "CLABE •••• 7829 · SPEI Activo",
            balanceFormatted: "$184,920.50",
            monthlyYieldFormatted: "+$2,410.80 este mes (11.2% GAT)",
            currency: "MXN"
        )
    }

    public func fetchRecentTransactions() -> [FintechTransactionItem] {
        [
            FintechTransactionItem(
                id: "tx-1",
                merchant: "Rendimiento Diario Cajita Turbo",
                category: "Inversión Automática",
                amountFormatted: "+$148.20",
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                isPositive: true
            ),
            FintechTransactionItem(
                id: "tx-2",
                merchant: "Apple Store Santa Fe",
                category: "Tecnología · Cashback aplicado",
                amountFormatted: "-$4,299.00",
                icon: "laptopcomputer",
                isPositive: false
            ),
            FintechTransactionItem(
                id: "tx-3",
                merchant: "Transferencia SPEI Recibida",
                category: "Depósito Interbancario",
                amountFormatted: "+$18,500.00",
                icon: "arrow.down.left.circle.fill",
                isPositive: true
            )
        ]
    }
}

public struct FintechCardEngineV0_1: FintechCardEngineProtocol {
    public init() {}
    public func fetchCardProduct() -> FintechCardProduct {
        FintechCardProduct(
            moduleVersionTag: "Module(\(FintechModuleV0_1.moduleVersion)) · MVP Beta",
            cardTitle: "Dagger Starter Virtual v0.1",
            cashbackText: "0% Cashback · Solo transferencias SPEI básicas",
            perks: [
                "Cuenta CLABE SPEI básica de lanzamiento (MVP 0.1)",
                "Tarjeta virtual para compras nacionales"
            ],
            isMetalV2: false
        )
    }
}

public struct FintechCardEngineV1: FintechCardEngineProtocol {
    public init() {}
    public func fetchCardProduct() -> FintechCardProduct {
        FintechCardProduct(
            moduleVersionTag: "Module(\(FintechModuleV1.moduleVersion)) · Release 1.0",
            cardTitle: "Dagger Classic Card v1.0",
            cashbackText: "1.5% Cashback en compras digitales",
            perks: [
                "Hereda Core Bancario SPEI de Module(0.1)",
                "1.5% Cashback y tarjeta física sin anualidad"
            ],
            isMetalV2: false
        )
    }
}

public struct FintechCardEngineV2: FintechCardEngineProtocol {
    public init() {}
    public func fetchCardProduct() -> FintechCardProduct {
        FintechCardProduct(
            moduleVersionTag: "Module(\(FintechModuleV2.moduleVersion)) · Metal 2.0",
            cardTitle: "Dagger Black Metal Card v2.0",
            cashbackText: "3.5% Cashback Instantáneo + Yield 11.2%",
            perks: [
                "Hereda Core Bancario SPEI sin repetir código",
                "3.5% Cashback directo a tu Cajita de Rendimiento",
                "Sala Lounge VIP + Seguro Internacional incluido"
            ],
            isMetalV2: true
        )
    }
}

@Module(1.0)
public enum FintechSharedFlagsModule {
    @Singleton
    public static func abFlagsRepository() -> any FintechABFlagsRepositoryProtocol {
        FintechABFlagsRepositoryImpl()
    }
}

/// Paleta 1: `@Module(0.1)` — MVP Beta con Core Bancario SPEI y Tarjeta Starter v0.1.
@Module(0.1, scope: FintechScope.self)
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

/// Paleta 2: `@Module(1.0)` — Conserva el Core Bancario de `0.1` y evoluciona a Classic Card 1.5%.
@Module(1.0, scope: FintechScope.self, includes: [FintechModuleV0_1.self])
public enum FintechModuleV1 {
    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV1()
    }
}

/// Paleta 3: `@Module(2.0)` — Conserva el Core Bancario y evoluciona a Black Metal Card 3.5% + Yield.
@Module(2.0, scope: FintechScope.self, includes: [FintechModuleV1.self])
public enum FintechModuleV2 {
    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV2()
    }
}
