//
//  FintechHomeViewModel.swift
//  FintechMockupDemo · Presentation -> ViewModel (MVVM)
//
//  Usa `FintechScope.Palette` (`ModulePalette` de la librería `DaggerSwift`, estilo `CodingKeys`)
//  y resolución explícita en compile-time (Cero `ScopeContainer`, cero `try!`, cero `try?`).
//

import SwiftUI
import DaggerSwift

@MainActor
@Inject(scope: FintechScope.self)
public final class FintechMockupViewModel: ObservableObject {
    public let initialDashboard: GetFintechDashboardUseCase
    public let flagsRepository: any FintechABFlagsRepositoryProtocol

    @Published public var selectedPalette: FintechScope.Palette = .v2_0
    @Published public var isWealthBentoVariantB: Bool = true
    @Published public var isInstantCreditBoostVariantB: Bool = true
    @Published public var dashboard: GetFintechDashboardUseCase?
    @Published public var transactions: [FintechTransactionItem] = []
    @Published public var boostActivatedMessage: String? = nil

    public func loadInitialDashboard() {
        guard dashboard == nil else { return }
        isWealthBentoVariantB = flagsRepository.isWealthBentoVariantB
        isInstantCreditBoostVariantB = flagsRepository.isInstantCreditBoostVariantB
        dashboard = initialDashboard
        Task {
            self.transactions = await initialDashboard.coreBanking.fetchRecentTransactions()
        }
    }

    public func selectPalette(_ option: FintechScope.Palette) {
        selectedPalette = option
        boostActivatedMessage = nil
        let updated = Self.makeDashboard(for: option, flags: flagsRepository)
        dashboard = updated
        Task {
            self.transactions = await updated.coreBanking.fetchRecentTransactions()
        }
    }

    public func toggleLayoutAB() {
        let next = !isWealthBentoVariantB
        isWealthBentoVariantB = next
        flagsRepository.setWealthBentoVariantB(next)
        dashboard = Self.makeDashboard(for: selectedPalette, flags: flagsRepository)
    }

    public func toggleCreditOfferAB() {
        let next = !isInstantCreditBoostVariantB
        isInstantCreditBoostVariantB = next
        flagsRepository.setInstantCreditBoostVariantB(next)
        boostActivatedMessage = nil
        dashboard = Self.makeDashboard(for: selectedPalette, flags: flagsRepository)
    }

    public func triggerCreditOfferCTA() {
        guard let offer = dashboard?.creditOfferVariant else { return }
        if offer.isInstantBoostEnabled {
            boostActivatedMessage = "✅ Depósito de \(offer.preapprovedAmountFormatted) acreditado."
        } else {
            boostActivatedMessage = "📋 Solicitud enviada a revisión (24-48 hrs)."
        }
    }

    public nonisolated static func makeDashboard(
        for option: FintechScope.Palette,
        flags: any FintechABFlagsRepositoryProtocol
    ) -> GetFintechDashboardUseCase {
        let module = FintechScope.module(for: option)
        return GetFintechDashboardUseCase(
            coreBanking: module.coreBanking(),
            cardEngine: module.cardEngine(),
            layoutVariant: FintechCoreModule.provideHomeLayoutVariant(flags: flags),
            creditOfferVariant: FintechCoreModule.provideCreditOfferVariant(flags: flags)
        )
    }
}
