//
//  CountryNewsEntities.swift
//  MultiCountryNewsDemo · Domain -> Entities
//

import Foundation
import DaggerSwift

/// Scope compartido por las variantes hermanas de país (México, USA, Brasil, Francia).
public enum CountryNewsScope: GraphScope {}

/// Precondición de Dominio: exige sesión activa en el país antes de resolver las noticias.
public struct AuthenticatedCountrySession: Precondition, Sendable, Equatable {
    public let country: SupportedCountry
    public let userIdentifier: String
    public let sessionToken: String

    public init(country: SupportedCountry, userIdentifier: String, sessionToken: String) {
        self.country = country
        self.userIdentifier = userIdentifier
        self.sessionToken = sessionToken
    }
}

public enum SupportedCountry: String, CaseIterable, Identifiable, Sendable {
    case mexico = "MX"
    case usa = "US"
    case brazil = "BR"
    case france = "FR"

    public var id: String { rawValue }

    public var flagEmoji: String {
        switch self {
        case .mexico: return "🇲🇽"
        case .usa: return "🇺🇸"
        case .brazil: return "🇧🇷"
        case .france: return "🇫🇷"
        }
    }

    public var displayName: String {
        switch self {
        case .mexico: return "México"
        case .usa: return "USA"
        case .brazil: return "Brasil"
        case .france: return "France"
        }
    }
}

public struct LocalizedCountryCopy: Sendable, Equatable {
    public let country: SupportedCountry
    public let languageCode: String
    public let regionBadge: String
    public let loginTitle: String
    public let loginSubtitle: String
    public let identifierPlaceholder: String
    public let defaultIdentifier: String
    public let loginButtonTitle: String
    public let logoutButtonTitle: String
    public let preconditionBlockedMessage: String
    public let newsHeaderTitle: String
    public let newsHeaderSubtitle: String
    public let breakingTag: String

    public init(
        country: SupportedCountry,
        languageCode: String,
        regionBadge: String,
        loginTitle: String,
        loginSubtitle: String,
        identifierPlaceholder: String,
        defaultIdentifier: String,
        loginButtonTitle: String,
        logoutButtonTitle: String,
        preconditionBlockedMessage: String,
        newsHeaderTitle: String,
        newsHeaderSubtitle: String,
        breakingTag: String
    ) {
        self.country = country
        self.languageCode = languageCode
        self.regionBadge = regionBadge
        self.loginTitle = loginTitle
        self.loginSubtitle = loginSubtitle
        self.identifierPlaceholder = identifierPlaceholder
        self.defaultIdentifier = defaultIdentifier
        self.loginButtonTitle = loginButtonTitle
        self.logoutButtonTitle = logoutButtonTitle
        self.preconditionBlockedMessage = preconditionBlockedMessage
        self.newsHeaderTitle = newsHeaderTitle
        self.newsHeaderSubtitle = newsHeaderSubtitle
        self.breakingTag = breakingTag
    }

    public static let empty = LocalizedCountryCopy(
        country: .mexico,
        languageCode: "es-MX",
        regionBadge: "🇲🇽 México",
        loginTitle: "",
        loginSubtitle: "",
        identifierPlaceholder: "",
        defaultIdentifier: "",
        loginButtonTitle: "",
        logoutButtonTitle: "",
        preconditionBlockedMessage: "",
        newsHeaderTitle: "",
        newsHeaderSubtitle: "",
        breakingTag: ""
    )
}

public struct NewsArticleItem: Identifiable, Sendable, Equatable {
    public let id: String
    public let category: String
    public let title: String
    public let summary: String
    public let readTime: String
    public let source: String
    public let symbolName: String

    public init(
        id: String,
        category: String,
        title: String,
        summary: String,
        readTime: String,
        source: String,
        symbolName: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.summary = summary
        self.readTime = readTime
        self.source = source
        self.symbolName = symbolName
    }
}
