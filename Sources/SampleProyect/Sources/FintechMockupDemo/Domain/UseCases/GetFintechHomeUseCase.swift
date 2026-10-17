//
//  GetFintechHomeUseCase.swift
//  FintechMockupDemo · Domain -> UseCases
//

import Foundation
import DaggerSwift

public enum FintechScope: GraphScope {}

@Inject
public struct GetFintechDashboardUseCase: Sendable {
    public let coreBanking: any FintechCoreBankingProtocol
    public let cardEngine: any FintechCardEngineProtocol
    public let layoutVariant: any FintechHomeLayoutVariantProtocol
    public let creditOfferVariant: any FintechCreditOfferVariantProtocol
}
