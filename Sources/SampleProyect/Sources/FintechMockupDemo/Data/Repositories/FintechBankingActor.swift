//
//  FintechBankingActor.swift
//  FintechMockupDemo · Data -> Repositories
//
//  Concurrencia Swift 6: `public actor` para el Core Bancario y `@MainActor` para los Feature Flags A/B
//  (Cero `NSLock`, Cero `@unchecked Sendable`).
//

import Foundation
import DaggerSwift

@Inject
public final class FintechABFlagsRepositoryImpl: FintechABFlagsRepositoryProtocol, Sendable {
    @MainActor private var wealthBentoB: Bool = true
    @MainActor private var creditBoostB: Bool = true

    public var isWealthBentoVariantB: Bool {
        MainActor.assumeIsolated { wealthBentoB }
    }

    public var isInstantCreditBoostVariantB: Bool {
        MainActor.assumeIsolated { creditBoostB }
    }

    public func setWealthBentoVariantB(_ enabled: Bool) {
        MainActor.assumeIsolated { wealthBentoB = enabled }
    }

    public func setInstantCreditBoostVariantB(_ enabled: Bool) {
        MainActor.assumeIsolated { creditBoostB = enabled }
    }
}

public actor FintechCoreBankingImpl: FintechCoreBankingProtocol {
    public init() {}

    nonisolated public func fetchAccountSummary() -> FintechAccountSummary {
        FintechAccountSummary(
            holderName: "Fernando Saldivar",
            accountNumberMasked: "CLABE •••• 7829",
            balanceFormatted: "$184,920.50",
            monthlyYieldFormatted: "+$2,410.80 este mes (11.2% GAT)",
            currency: "MXN"
        )
    }

    public func fetchRecentTransactions() async -> [FintechTransactionItem] {
        [
            FintechTransactionItem(
                id: "tx-1",
                merchant: "Rendimiento Cajita Turbo",
                category: "Inversión Automática",
                amountFormatted: "+$148.20",
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                isPositive: true
            ),
            FintechTransactionItem(
                id: "tx-2",
                merchant: "Apple Store Santa Fe",
                category: "Compras · Cashback aplicado",
                amountFormatted: "-$4,299.00",
                icon: "laptopcomputer",
                isPositive: false
            ),
            FintechTransactionItem(
                id: "tx-3",
                merchant: "Transferencia SPEI",
                category: "Depósito recibido",
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
            moduleVersionTag: "Module(\(FintechModuleV0_1.moduleVersion))",
            cardTitle: "Dagger Starter Virtual",
            cashbackText: "0% Cashback · Cuenta SPEI básica",
            perks: [
                "Transferencias SPEI nacionales",
                "Tarjeta virtual de lanzamiento"
            ],
            isMetalV2: false
        )
    }
}

public struct FintechCardEngineV1: FintechCardEngineProtocol {
    public init() {}
    public func fetchCardProduct() -> FintechCardProduct {
        FintechCardProduct(
            moduleVersionTag: "Module(\(FintechModuleV1.moduleVersion))",
            cardTitle: "Dagger Classic Card",
            cashbackText: "1.5% Cashback en compras digitales",
            perks: [
                "1.5% Cashback en todas tus compras",
                "Tarjeta física y virtual sin anualidad"
            ],
            isMetalV2: false
        )
    }
}

public struct FintechCardEngineV2: FintechCardEngineProtocol {
    public init() {}
    public func fetchCardProduct() -> FintechCardProduct {
        FintechCardProduct(
            moduleVersionTag: "Module(\(FintechModuleV2.moduleVersion))",
            cardTitle: "Dagger Black Metal",
            cashbackText: "3.5% Cashback + Rendimiento 11.2%",
            perks: [
                "3.5% Cashback directo a tu inversión",
                "Acceso VIP Lounge y seguro internacional"
            ],
            isMetalV2: true
        )
    }
}
