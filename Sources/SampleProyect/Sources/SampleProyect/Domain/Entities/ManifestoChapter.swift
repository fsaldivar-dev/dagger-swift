//
//  ManifestoChapter.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Entity
//  Representa un capítulo del Manifiesto Open Source y Memoria Técnica de DaggerSwift.
//

import Foundation

public struct ManifestoChapter: Identifiable, Sendable, Equatable {
    public let id: String
    public let badge: String
    public let title: String
    public let subtitle: String
    public let quote: String
    public let paragraphs: [String]

    public init(
        id: String,
        badge: String,
        title: String,
        subtitle: String,
        quote: String,
        paragraphs: [String]
    ) {
        self.id = id
        self.badge = badge
        self.title = title
        self.subtitle = subtitle
        self.quote = quote
        self.paragraphs = paragraphs
    }
}
