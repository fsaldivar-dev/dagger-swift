//
//  ValidatedSession.swift
//  Core
//
//  Capa Core · Precondición de Grafo (@Precondition).
//  Representa una sesión activa validada. Si devuelve nil, el grafo aborta antes de instanciar.
//

import Foundation
import DaggerSwift

public struct ValidatedSession: Precondition, Sendable, Equatable {
    public let username: String
    public let tokenFingerprint: String
    public let authenticatedAt: Date

    public init(username: String, tokenFingerprint: String, authenticatedAt: Date = Date()) {
        self.username = username
        self.tokenFingerprint = tokenFingerprint
        self.authenticatedAt = authenticatedAt
    }
}
