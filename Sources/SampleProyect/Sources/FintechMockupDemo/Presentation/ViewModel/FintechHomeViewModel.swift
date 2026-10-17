//
//  FintechHomeViewModel.swift
//  FintechMockupDemo · Presentation -> ViewModel (MVVM)
//
//  Usa únicamente el decorador `@Inject(scope: FintechScope.self)` y los `@Module`s
//  sin referenciar `ScopeContainer`.
//

import SwiftUI
import DaggerSwift

public enum FintechModulePaletteOption: String, CaseIterable, Identifiable, Sendable {
    case v0_1 = "0.1"
    case v1_0 = "1.0"
    case v2_0 = "2.0"

    public var id: String { rawValue }

    public var moduleType: any GraphModule.Type {
        switch self {
        case .v0_1: return FintechModuleV0_1.self
        case .v1_0: return FintechModuleV1.self
        case .v2_0: return FintechModuleV2.self
        }
    }

    public var buttonLabel: String {
        "Module(\(moduleType.moduleVersion))"
    }
}

@MainActor
@Inject(scope: FintechScope.self)
public final class FintechMockupViewModel: ObservableObject {
    public let initialDashboard: GetFintechDashboardUseCase
    public let flagsRepository: any FintechABFlagsRepositoryProtocol

    @Published public var selectedPalette: FintechModulePaletteOption = .v2_0
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

    public func selectPalette(_ option: FintechModulePaletteOption) {
        selectedPalette.moduleType.teardownScope()
        selectedPalette = option
        boostActivatedMessage = nil

        if let updated = try? option.moduleType.resolve(GetFintechDashboardUseCase.self) {
            dashboard = updated
            Task {
                self.transactions = await updated.coreBanking.fetchRecentTransactions()
            }
        }
    }

    public func toggleLayoutAB() {
        let next = !isWealthBentoVariantB
        isWealthBentoVariantB = next
        flagsRepository.setWealthBentoVariantB(next)
        refreshDashboardFromGraph()
    }

    public func toggleCreditOfferAB() {
        let next = !isInstantCreditBoostVariantB
        isInstantCreditBoostVariantB = next
        flagsRepository.setInstantCreditBoostVariantB(next)
        boostActivatedMessage = nil
        refreshDashboardFromGraph()
    }

    public func triggerCreditOfferCTA() {
        guard let offer = dashboard?.creditOfferVariant else { return }
        if offer.isInstantBoostEnabled {
            boostActivatedMessage = "✅ Depósito de \(offer.preapprovedAmountFormatted) acreditado."
        } else {
            boostActivatedMessage = "📋 Solicitud enviada a revisión (24-48 hrs)."
        }
    }

    private func refreshDashboardFromGraph() {
        guard let updated = try? selectedPalette.moduleType.resolve(GetFintechDashboardUseCase.self) else { return }
        dashboard = updated
    }
}
