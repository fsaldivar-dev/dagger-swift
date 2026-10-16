//
//  ToggleExplorerVariantUseCase.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Use Case
//  Alterna el estado del Feature Flag para conmutar la Regla de Negocio del explorador.
//

import Foundation

public struct ToggleExplorerVariantUseCase: Sendable {
    private let featureFlagRepository: any FeatureFlagRepositoryProtocol

    public init(featureFlagRepository: any FeatureFlagRepositoryProtocol) {
        self.featureFlagRepository = featureFlagRepository
    }

    public var isBentoV2Enabled: Bool {
        featureFlagRepository.isBentoV2Enabled
    }

    public func execute(enableBentoV2: Bool) {
        featureFlagRepository.setBentoV2(enableBentoV2)
    }
}
