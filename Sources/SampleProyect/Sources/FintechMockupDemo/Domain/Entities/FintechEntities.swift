//
//  FintechEntities.swift
//  FintechMockupDemo · Domain -> Entities
//

import Foundation
import DaggerSwift

public enum FintechScope: GraphScope {}

public struct FintechAccountSummary: Sendable, Equatable {
    public let holderName: String
    public let accountNumberMasked: String
    public let balanceFormatted: String
    public let monthlyYieldFormatted: String
    public let currency: String

    public init(
        holderName: String,
        accountNumberMasked: String,
        balanceFormatted: String,
        monthlyYieldFormatted: String,
        currency: String
    ) {
        self.holderName = holderName
        self.accountNumberMasked = accountNumberMasked
        self.balanceFormatted = balanceFormatted
        self.monthlyYieldFormatted = monthlyYieldFormatted
        self.currency = currency
    }
}

public struct FintechCardProduct: Sendable, Equatable {
    public let moduleVersionTag: String
    public let cardTitle: String
    public let cashbackText: String
    public let perks: [String]
    public let isMetalV2: Bool

    public init(
        moduleVersionTag: String,
        cardTitle: String,
        cashbackText: String,
        perks: [String],
        isMetalV2: Bool
    ) {
        self.moduleVersionTag = moduleVersionTag
        self.cardTitle = cardTitle
        self.cashbackText = cashbackText
        self.perks = perks
        self.isMetalV2 = isMetalV2
    }
}

public struct FintechTransactionItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let merchant: String
    public let category: String
    public let amountFormatted: String
    public let icon: String
    public let isPositive: Bool

    public init(
        id: String,
        merchant: String,
        category: String,
        amountFormatted: String,
        icon: String,
        isPositive: Bool = false
    ) {
        self.id = id
        self.merchant = merchant
        self.category = category
        self.amountFormatted = amountFormatted
        self.icon = icon
        self.isPositive = isPositive
    }
}

public protocol FintechHomeLayoutVariantProtocol: Sendable {
    var variantCode: String { get }
    var badgeTitle: String { get }
    var subtitle: String { get }
    var showsWealthAnalyticsChart: Bool { get }
}

public protocol FintechCreditOfferVariantProtocol: Sendable {
    var experimentCode: String { get }
    var bannerTitle: String { get }
    var bannerSubtitle: String { get }
    var preapprovedAmountFormatted: String { get }
    var ctaTitle: String { get }
    var isInstantBoostEnabled: Bool { get }
}

public struct ClassicBalanceLayoutVariant: FintechHomeLayoutVariantProtocol {
    public let variantCode = "A"
    public let badgeTitle = "Variante A · Clásica"
    public let subtitle = "Vista simple de saldo"
    public let showsWealthAnalyticsChart = false
    public init() {}
}

public struct WealthBentoLayoutVariant: FintechHomeLayoutVariantProtocol {
    public let variantCode = "B"
    public let badgeTitle = "Variante B · Wealth Bento"
    public let subtitle = "Gráfica de rendimiento activa"
    public let showsWealthAnalyticsChart = true
    public init() {}
}

public struct StandardCreditOfferVariant: FintechCreditOfferVariantProtocol {
    public let experimentCode = "Control-A"
    public let bannerTitle = "Línea de Crédito Tradicional"
    public let bannerSubtitle = "Revisión estándar en 24-48 hrs"
    public let preapprovedAmountFormatted = "$25,000 MXN"
    public let ctaTitle = "Solicitar"
    public let isInstantBoostEnabled = false
    public init() {}
}

public struct InstantBoostCreditOfferVariant: FintechCreditOfferVariantProtocol {
    public let experimentCode = "Exp-B"
    public let bannerTitle = "⚡ 1-Click Credit Boost"
    public let bannerSubtitle = "Depósito inmediato pre-aprobado"
    public let preapprovedAmountFormatted = "$120,000 MXN"
    public let ctaTitle = "Activar Ahora"
    public let isInstantBoostEnabled = true
    public init() {}
}
