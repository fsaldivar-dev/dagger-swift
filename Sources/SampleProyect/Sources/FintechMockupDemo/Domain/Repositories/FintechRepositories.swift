//
//  FintechRepositories.swift
//  FintechMockupDemo · Domain -> Repositories
//

import Foundation
import DaggerSwift

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

/// Contrato en tiempo de compilación para la familia de módulos `Module(0.1)`, `Module(1.0)` y `Module(2.0)`.
public protocol FintechModuleContract: GraphModule {
    static func coreBanking() -> any FintechCoreBankingProtocol
    static func cardEngine() -> any FintechCardEngineProtocol
}
