//
//  FeatureFlagRepositoryImpl.swift
//  SampleProyect
//
//  Clean Architecture · Data Layer · Repository Implementation
//  Almacén concurrente para los feature flags en tiempo de ejecución.
//

import Foundation

public final class FeatureFlagRepositoryImpl: FeatureFlagRepositoryProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var bentoV2: Bool

    public init(isBentoV2Enabled: Bool = true) {
        self.bentoV2 = isBentoV2Enabled
    }

    public var isBentoV2Enabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return bentoV2
    }

    public func setBentoV2(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        bentoV2 = enabled
    }
}

// Retro-compatibilidad con código v2 previo
public typealias FeatureFlagStateBox = FeatureFlagRepositoryImpl
