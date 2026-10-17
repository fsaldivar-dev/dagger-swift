//
//  GetFintechHomeUseCase.swift
//  FintechMockupDemo · Domain -> UseCases
//

import Foundation
import DaggerSwift

public enum FintechScope: GraphScope {}

public struct FintechDashboardSnapshot: Sendable {
    public let account: FintechAccountSummary
    public let card: FintechCardProduct
    public let layoutVariant: any FintechHomeLayoutVariantProtocol
    public let creditOfferVariant: any FintechCreditOfferVariantProtocol
    public let transactions: [FintechTransactionItem]

    public init(
        account: FintechAccountSummary,
        card: FintechCardProduct,
        layoutVariant: any FintechHomeLayoutVariantProtocol,
        creditOfferVariant: any FintechCreditOfferVariantProtocol,
        transactions: [FintechTransactionItem]
    ) {
        self.account = account
        self.card = card
        self.layoutVariant = layoutVariant
        self.creditOfferVariant = creditOfferVariant
        self.transactions = transactions
    }
}

/// Caso de Uso de Dominio (`@Inject`):
/// Encapsula `coreBanking` y `cardEngine` (Ley de Demeter) y expone `execute()`.
@Inject
public struct GetFintechDashboardUseCase: Sendable {
    let coreBanking: any FintechCoreBankingProtocol
    let cardEngine: any FintechCardEngineProtocol
    public let layoutVariant: any FintechHomeLayoutVariantProtocol
    public let creditOfferVariant: any FintechCreditOfferVariantProtocol

    public var accountSummary: FintechAccountSummary { coreBanking.fetchAccountSummary() }
    public var cardProduct: FintechCardProduct { cardEngine.fetchCardProduct() }

    public func execute() async -> FintechDashboardSnapshot {
        let transactions = await coreBanking.fetchRecentTransactions()
        return FintechDashboardSnapshot(
            account: coreBanking.fetchAccountSummary(),
            card: cardEngine.fetchCardProduct(),
            layoutVariant: layoutVariant,
            creditOfferVariant: creditOfferVariant,
            transactions: transactions
        )
    }
}
