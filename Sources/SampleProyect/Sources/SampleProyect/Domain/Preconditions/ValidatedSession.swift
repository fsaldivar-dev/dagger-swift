//
//  ValidatedSession.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Precondition
//  Token de sesión validado exigido por el grafo de DaggerSwift v2
//  antes de autorizar la instanciación de submódulos protegidos en RAM.
//

import Foundation
import DaggerSwift

public struct ValidatedSession: Precondition, Sendable, Equatable {
    public let userID: String
    public let username: String
    public let tokenPreview: String
    public let role: String
    public let authenticatedAt: Date

    public init(
        userID: String = "16517868",
        username: String = "fsaldivar-dev",
        tokenPreview: String = "mock_session_token_demo",
        role: String = "Owner & Architect",
        authenticatedAt: Date = Date()
    ) {
        self.userID = userID
        self.username = username
        self.tokenPreview = tokenPreview
        self.role = role
        self.authenticatedAt = authenticatedAt
    }
}
