//
//  FintechComposer.swift
//  FintechMockupDemo · Composition Root (SOLID)
//
//  Responsabilidad Única (SRP + DIP): Ensambla la paleta `@Scope` (`Module(0.1)`, `Module(1.0)`, `Module(2.0)`)
//  y las reglas de negocio `@BusinessRule` con el `GetFintechDashboardUseCase` y el `FintechMockupViewModel`.
//

import SwiftUI
import DaggerSwift

public protocol FintechComposing: Sendable {
    func makeDashboard(
        for palette: FintechScope.Palette,
        flags: any FintechABFlagsRepositoryProtocol
    ) -> GetFintechDashboardUseCase
}

@Inject
public struct FintechComposer: FintechComposing {
    public func makeDashboard(
        for palette: FintechScope.Palette,
        flags: any FintechABFlagsRepositoryProtocol
    ) -> GetFintechDashboardUseCase {
        let module = FintechScope.module(for: palette)
        return GetFintechDashboardUseCase(
            coreBanking: module.coreBanking(),
            cardEngine: module.cardEngine(),
            layoutVariant: FintechCoreModule.provideHomeLayoutVariant(flags: flags),
            creditOfferVariant: FintechCoreModule.provideCreditOfferVariant(flags: flags)
        )
    }

    @MainActor
    public static func compose(
        initialPalette: FintechScope.Palette = .v2_0,
        flagsRepository: any FintechABFlagsRepositoryProtocol = FintechSharedFlagsModule.abFlagsRepository()
    ) -> FintechMockupFeatureView {
        let composer = FintechComposer()
        let viewModel = FintechMockupViewModel(
            initialDashboard: composer.makeDashboard(for: initialPalette, flags: flagsRepository),
            flagsRepository: flagsRepository,
            composer: composer
        )
        return FintechMockupFeatureView(viewModel: viewModel)
    }
}
