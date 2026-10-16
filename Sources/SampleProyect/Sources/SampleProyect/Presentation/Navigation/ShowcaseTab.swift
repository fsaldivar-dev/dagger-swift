//
//  ShowcaseTab.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Navigation Model
//

import Foundation

public enum ShowcaseTab: String, CaseIterable, Identifiable, Sendable {
    case repositories = "Repositorios"
    case deepLinks    = "Deep Links & Auth"
    case manifesto    = "Manifiesto"
    case graphMonitor = "Grafo & RAM"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .repositories: return "shippingbox.fill"
        case .deepLinks:    return "link.badge.plus"
        case .manifesto:    return "book.pages.fill"
        case .graphMonitor: return "point.3.connected.trianglepath.dotted"
        }
    }
}
