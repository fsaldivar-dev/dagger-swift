//
//  FintechHomeViewModel.swift
//  FintechMockupDemo · Presentation -> ViewModel (MVVM)
//
//  Plug & UnPlug + Clean Architecture:
//  - Depende de `GetFintechDashboardUseCase` y `FintechABFlagsRepositoryProtocol` vía `@Inject`.
//  - Al cambiar entre `Module(0.1)`, `Module(1.0)` y `Module(2.0)`, hace `teardownScope()` (UnPlug)
//    del módulo anterior y ejecuta `execute()` del nuevo módulo (Plug).
//

import SwiftUI
import DaggerSwift

@MainActor
@Inject(scope: FintechScope.self)
public final class FintechMockupViewModel: ObservableObject {
    public let flagsRepository: any FintechABFlagsRepositoryProtocol

    @Published public var selectedPalette: FintechScope.Palette = .v2_0
    @Published public var isWealthBentoVariantB: Bool = true
    @Published public var isInstantCreditBoostVariantB: Bool = true
    @Published public var snapshot: FintechDashboardSnapshot?
    @Published public var boostActivatedMessage: String? = nil

    public func loadInitialDashboard() async {
        guard snapshot == nil else { return }
        isWealthBentoVariantB = flagsRepository.isWealthBentoVariantB
        isInstantCreditBoostVariantB = flagsRepository.isInstantCreditBoostVariantB
        await reloadFromActiveModule()
    }

    /// Plug & UnPlug: Desconecta la versión anterior de la paleta y conecta la nueva (`0.1`, `1.0` o `2.0`).
    public func selectPalette(_ option: FintechScope.Palette) {
        let previousModule = FintechScope.module(for: selectedPalette)
        previousModule.teardownScope()

        selectedPalette = option
        boostActivatedMessage = nil
        Task { await reloadFromActiveModule() }
    }

    public func toggleLayoutAB() {
        let next = !isWealthBentoVariantB
        isWealthBentoVariantB = next
        flagsRepository.setWealthBentoVariantB(next)
        Task { await reloadFromActiveModule() }
    }

    public func toggleCreditOfferAB() {
        let next = !isInstantCreditBoostVariantB
        isInstantCreditBoostVariantB = next
        flagsRepository.setInstantCreditBoostVariantB(next)
        boostActivatedMessage = nil
        Task { await reloadFromActiveModule() }
    }

    public func triggerCreditOfferCTA() {
        guard let offer = snapshot?.creditOfferVariant else { return }
        if offer.isInstantBoostEnabled {
            boostActivatedMessage = "✅ Depósito de \(offer.preapprovedAmountFormatted) acreditado."
        } else {
            boostActivatedMessage = "📋 Solicitud enviada a revisión (24-48 hrs)."
        }
    }

    private func reloadFromActiveModule() async {
        let activeModule = FintechScope.module(for: selectedPalette)
        let useCase = activeModule.makeDashboardUseCase(
            layoutVariant: FintechCoreModule.provideHomeLayoutVariant(flags: flagsRepository),
            creditOfferVariant: FintechCoreModule.provideCreditOfferVariant(flags: flagsRepository)
        )
        self.snapshot = await useCase.execute()
    }
}
