//
//  FintechModules.swift
//  Services
//
//  Demo 2 · Evolución de Módulo (`FintechModuleV1` -> `FintechModuleV2` con `@Module(includes:)`)
//  y repositorio reactivo de Feature Flags A/B para `@BusinessRule`.
//

import Foundation
import DaggerSwift
import AppFoundation
import Core

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

public struct FintechCardEngineV1: FintechCardEngineProtocol {
    public init() {}
    public func fetchCardProduct() -> FintechCardProduct {
        FintechCardProduct(
            moduleVersionTag: "FintechModuleV1 (v1.0)",
            cardTitle: "Dagger Classic Card v1",
            cashbackText: "1.5% Cashback en compras digitales",
            perks: [
                "Transferencias SPEI sin comisión",
                "Tarjeta virtual con CVV dinámico"
            ],
            isMetalV2: false
        )
    }
}

public struct FintechCardEngineV2: FintechCardEngineProtocol {
    public init() {}
    public func fetchCardProduct() -> FintechCardProduct {
        FintechCardProduct(
            moduleVersionTag: "FintechModuleV2 (v2.0 · includes V1)",
            cardTitle: "Dagger Black Metal Card v2",
            cashbackText: "3.5% Cashback Instantáneo + Yield 11.2%",
            perks: [
                "Hereda Core Bancario SPEI de V1 sin repetirlo",
                "3.5% Cashback directo a tu Cajita de Rendimiento",
                "Sala Lounge VIP + Seguro Internacional incluido"
            ],
            isMetalV2: true
        )
    }
}

@Module
public enum FintechSharedFlagsModule {
    @Singleton
    public static func abFlagsRepository() -> any FintechABFlagsRepositoryProtocol {
        FintechABFlagsRepositoryImpl()
    }
}

/// Versión 1.0 del Módulo Fintech: registra el Core Bancario y el Motor de Tarjeta Clásica V1.
@Module(scope: FintechScope.self)
public enum FintechModuleV1 {
    @Scoped
    public static func coreBanking() -> any FintechCoreBankingProtocol {
        FintechCoreBankingImpl()
    }

    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV1()
    }
}

/// Versión 2.0 del Módulo Fintech:
/// Usa `@Module(scope: FintechScope.self, includes: [FintechModuleV1.self])` para conservar
/// intacto el `coreBanking()` de la V1 y reemplazar únicamente `cardEngine()` por `FintechCardEngineV2`.
@Module(scope: FintechScope.self, includes: [FintechModuleV1.self])
public enum FintechModuleV2 {
    @Scoped
    public static func cardEngine() -> any FintechCardEngineProtocol {
        FintechCardEngineV2()
    }
}
