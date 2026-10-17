//
//  FintechHomeViewModel.swift
//  FintechMockupDemo · Presentation -> ViewModel (MVVM)
//
//  Cumple SRP y DIP (SOLID): depende únicamente de abstracciones (`GetFintechDashboardUseCase`,
//  `FintechABFlagsRepositoryProtocol`, `FintechComposing`) inyectadas con `@Inject`.
//

import SwiftUI
import DaggerSwift

@MainActor
@Inject(scope: FintechScope.self)
public final class FintechMockupViewModel: ObservableObject {
    public let initialDashboard: GetFintechDashboardUseCase
    public let flagsRepository: any FintechABFlagsRepositoryProtocol
    public let composer: any FintechComposing

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
        let updated = composer.makeDashboard(for: option, flags: flagsRepository)
        dashboard = updated
        Task {
            self.transactions = await updated.coreBanking.fetchRecentTransactions()
        }
    }

    public func toggleLayoutAB() {
        let next = !isWealthBentoVariantB
        isWealthBentoVariantB = next
        flagsRepository.setWealthBentoVariantB(next)
        dashboard = composer.makeDashboard(for: selectedPalette, flags: flagsRepository)
    }

    public func toggleCreditOfferAB() {
        let next = !isInstantCreditBoostVariantB
        isInstantCreditBoostVariantB = next
        flagsRepository.setInstantCreditBoostVariantB(next)
        boostActivatedMessage = nil
        dashboard = composer.makeDashboard(for: selectedPalette, flags: flagsRepository)
    }

    public func triggerCreditOfferCTA() {
        guard let offer = dashboard?.creditOfferVariant else { return }
        if offer.isInstantBoostEnabled {
            boostActivatedMessage = "✅ Depósito de \(offer.preapprovedAmountFormatted) acreditado."
        } else {
            boostActivatedMessage = "📋 Solicitud enviada a revisión (24-48 hrs)."
        }
    }
}
