//
//  FeatureFlagRepository.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Repository Protocol
//  Define el contrato para consultar y alterar Feature Flags del sistema.
//

import Foundation

public protocol FeatureFlagRepositoryProtocol: Sendable {
    var isBentoV2Enabled: Bool { get }
    func setBentoV2(_ enabled: Bool)
}
