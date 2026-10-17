//
//  FintechCore.swift
//  Core
//
//  Demo 2 · Capa Core para la App Mockup de Fintech:
//  Combina evolución de módulo (`FintechModuleV1` -> `FintechModuleV2`)
//  con dos reglas `@BusinessRule` (A/B Layout y A/B Credit Boost).
//

import Foundation
import DaggerSwift
import AppFoundation

public enum FintechScope: GraphScope {}

public protocol FintechCoreBankingProtocol: Sendable {
    func fetchAccountSummary() -> FintechAccountSummary
    func fetchRecentTransactions() -> [FintechTransactionItem]
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
    public let badgeTitle = "Layout A · Clásico Compacto"
    public let subtitle = "Vista tradicional de saldo y lista simple"
    public let showsWealthAnalyticsChart = false
    public init() {}
}

public struct WealthBentoLayoutVariant: FintechHomeLayoutVariantProtocol {
    public let variantCode = "B"
    public let badgeTitle = "Layout B · Wealth Bento Pro"
    public let subtitle = "Tarjetas Bento con gráfica de rendimiento y acciones rápidas"
    public let showsWealthAnalyticsChart = true
    public init() {}
}

public struct StandardCreditOfferVariant: FintechCreditOfferVariantProtocol {
    public let experimentCode = "Control-A"
    public let bannerTitle = "Línea de Crédito Tradicional"
    public let bannerSubtitle = "Sujeto a evaluación de buró (24-48 hrs)"
    public let preapprovedAmountFormatted = "$25,000 MXN"
    public let ctaTitle = "Solicitar Evaluación"
    public let isInstantBoostEnabled = false
    public init() {}
}

public struct InstantBoostCreditOfferVariant: FintechCreditOfferVariantProtocol {
    public let experimentCode = "Exp-B"
    public let bannerTitle = "⚡ 1-Click Credit Boost Pre-Aprobado"
    public let bannerSubtitle = "Experimento B activo: depósito inmediato sin papeleo"
    public let preapprovedAmountFormatted = "$120,000 MXN"
    public let ctaTitle = "Activar $120,000 Ahora"
    public let isInstantBoostEnabled = true
    public init() {}
}

@Module
public enum FintechCoreModule {
    /// `@BusinessRule` 1: Conmuta en vivo entre el Layout A (Clásico) y Layout B (Wealth Bento).
    @BusinessRule
    public static func provideHomeLayoutVariant(
        flags: any FintechABFlagsRepositoryProtocol
    ) -> any FintechHomeLayoutVariantProtocol {
        flags.isWealthBentoVariantB ? WealthBentoLayoutVariant() : ClassicBalanceLayoutVariant()
    }

    /// `@BusinessRule` 2: Conmuta en vivo entre el experimento A/B de oferta de crédito.
    @BusinessRule
    public static func provideCreditOfferVariant(
        flags: any FintechABFlagsRepositoryProtocol
    ) -> any FintechCreditOfferVariantProtocol {
        flags.isInstantCreditBoostVariantB ? InstantBoostCreditOfferVariant() : StandardCreditOfferVariant()
    }
}

/// Hijo con estado atado al Scope (`@Inject(scope: FintechScope.self)`):
/// Funciona tanto en `FintechModuleV1` como en `FintechModuleV2`.
@Inject(scope: FintechScope.self)
public final class FintechSessionInspector: Sendable {
    public let coreBanking: any FintechCoreBankingProtocol
    public let cardEngine: any FintechCardEngineProtocol
}

/// Caso de Uso `@Inject` que combina el `FintechSessionInspector` (`@Scoped` en `FintechScope`)
/// con la evaluación en tiempo real de las reglas `@BusinessRule` (A/B Layout y A/B Credit Offer).
@Inject
public struct GetFintechDashboardUseCase: Sendable {
    public let inspector: FintechSessionInspector
    public let layoutVariant: any FintechHomeLayoutVariantProtocol
    public let creditOfferVariant: any FintechCreditOfferVariantProtocol

    public var coreBanking: any FintechCoreBankingProtocol { inspector.coreBanking }
    public var cardEngine: any FintechCardEngineProtocol { inspector.cardEngine }
}
