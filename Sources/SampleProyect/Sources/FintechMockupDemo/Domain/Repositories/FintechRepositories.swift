//
//  FintechRepositories.swift
//  FintechMockupDemo · Domain -> Repositories
//

import Foundation

public protocol FintechCoreBankingProtocol: Sendable {
    func fetchAccountSummary() -> FintechAccountSummary
    func fetchRecentTransactions() async -> [FintechTransactionItem]
}

public protocol FintechCardEngineProtocol: Sendable {
    func fetchCardProduct() -> FintechCardProduct
}

public protocol FintechABFlagsRepositoryProtocol: Sendable {
    var isWealthBentoVariantB: Bool { get }
    var isInstantCreditBoostVariantB: Bool { get }
    func setWealthBentoVariantB(_ enabled: Bool)
    func setInstantCreditBoostVariantB(_ enabled: Bool)
}
