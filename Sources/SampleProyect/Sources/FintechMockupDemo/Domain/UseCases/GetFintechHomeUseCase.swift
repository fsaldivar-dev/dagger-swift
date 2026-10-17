//
//  GetFintechHomeUseCase.swift
//  FintechMockupDemo · Domain -> UseCases
//

import Foundation
import DaggerSwift

@Inject(scope: FintechScope.self)
public final class FintechSessionInspector: Sendable {
    public let coreBanking: any FintechCoreBankingProtocol
    public let cardEngine: any FintechCardEngineProtocol
}

@Inject
public struct GetFintechDashboardUseCase: Sendable {
    public let inspector: FintechSessionInspector
    public let layoutVariant: any FintechHomeLayoutVariantProtocol
    public let creditOfferVariant: any FintechCreditOfferVariantProtocol

    public var coreBanking: any FintechCoreBankingProtocol { inspector.coreBanking }
    public var cardEngine: any FintechCardEngineProtocol { inspector.cardEngine }
}
