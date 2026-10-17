//
//  FintechHomeViewModel.swift
//  FintechMockupDemo · Presentation -> ViewModel (MVVM)
//
//  Usa `@Inject`: cero `init` manual y cero `rootContainer.resolve` en el inicializador.
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
@Inject
public final class FintechMockupViewModel: ObservableObject {
    public let flagsRepository: any FintechABFlagsRepositoryProtocol
    public let container: ScopeContainer

    private var activeFintechScope: ScopeContainer?

    @Published public var selectedPalette: FintechModulePaletteOption = .v2_0
    @Published public var isWealthBentoVariantB: Bool = true
    @Published public var isInstantCreditBoostVariantB: Bool = true
    @Published public var dashboard: GetFintechDashboardUseCase?
    @Published public var transactions: [FintechTransactionItem] = []
    @Published public var boostActivatedMessage: String? = nil

    public func loadInitialDashboard() {
        guard activeFintechScope == nil else { return }
        isWealthBentoVariantB = flagsRepository.isWealthBentoVariantB
        isInstantCreditBoostVariantB = flagsRepository.isInstantCreditBoostVariantB
        selectPalette(selectedPalette)
    }

    public func selectPalette(_ option: FintechModulePaletteOption) {
        selectedPalette = option
        boostActivatedMessage = nil
        activeFintechScope?.teardown()

        let newScope = container.makeChildScope(for: option.moduleType)
        activeFintechScope = newScope
        if let updated = try? newScope.resolve(GetFintechDashboardUseCase.self) {
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
        guard let scope = activeFintechScope,
              let updated = try? scope.resolve(GetFintechDashboardUseCase.self) else { return }
        dashboard = updated
    }
}
