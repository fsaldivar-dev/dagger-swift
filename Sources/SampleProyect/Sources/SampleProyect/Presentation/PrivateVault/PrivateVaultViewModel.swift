//
//  PrivateVaultViewModel.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · MVVM ViewModel (Scoped)
//  Gobierna la bóveda privada asegurada por la precondición `ValidatedSession`.
//

import Foundation
import SwiftUI
import DaggerSwift

@MainActor
public final class PrivateVaultViewModel: ObservableObject {
    public let vault: PrivateVaultInteractor
    public let scope: ScopeContainer

    public init(session: ActiveVaultSession) {
        self.vault = session.vault
        self.scope = session.scope
    }

    public var username: String {
        vault.session.username
    }

    public var keys: [String] {
        vault.secretKeys
    }

    public var instanceID: String {
        vault.instanceID
    }
}
