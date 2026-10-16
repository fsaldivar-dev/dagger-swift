//
//  ExplorerLayoutVariant.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Business Rule Strategy
//  Estrategia polimórfica inyectada dinámicamente por `@BusinessRule`
//  para alternar entre la UI clásica (v1) y la cuadrícula Bento (v2).
//

import Foundation

public enum ExplorerLayoutVariant: String, Sendable, Equatable {
    case classicV1 = "Sistema A · Lista Clásica (v1)"
    case bentoV2   = "Sistema B · Bento + Telemetría DAG (v2)"
}

public protocol RepoExplorerStrategyProtocol: Sendable {
    var variant: ExplorerLayoutVariant { get }
    var badgeTitle: String { get }
    var accentDescription: String { get }
    var showsArchitectureTelemetry: Bool { get }
    var usesBentoGrid: Bool { get }
}
