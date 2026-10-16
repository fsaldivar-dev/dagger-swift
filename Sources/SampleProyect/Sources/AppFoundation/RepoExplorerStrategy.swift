//
//  RepoExplorerStrategy.swift
//  AppFoundation
//
//  Capa Foundation · Modelo de Estrategia para @BusinessRule (Bento v2 vs Compacto v1).
//

import Foundation

public enum ExplorerLayoutVariant: String, Sendable, Equatable {
    case classicV1 = "Compacto v1"
    case bentoV2 = "Bento Social v2"
}

public protocol RepoExplorerStrategyProtocol: Sendable {
    var variant: ExplorerLayoutVariant { get }
    var badgeTitle: String { get }
    var accentDescription: String { get }
    var usesBentoGrid: Bool { get }
}

public struct RepoExplorerStrategy: RepoExplorerStrategyProtocol, Sendable, Equatable {
    public let variant: ExplorerLayoutVariant

    public init(variant: ExplorerLayoutVariant) {
        self.variant = variant
    }

    public var usesBentoGrid: Bool {
        variant == .bentoV2
    }

    public var badgeTitle: String {
        usesBentoGrid ? "BENTO V2" : "COMPACTO V1"
    }

    public var accentDescription: String {
        usesBentoGrid
            ? "Tarjetas sociales enriquecidas inyectadas por @BusinessRule."
            : "Lista compacta clásica inyectada cuando el Feature Flag se apaga."
    }

    public static let bento = RepoExplorerStrategy(variant: .bentoV2)
    public static let classic = RepoExplorerStrategy(variant: .classicV1)
}
