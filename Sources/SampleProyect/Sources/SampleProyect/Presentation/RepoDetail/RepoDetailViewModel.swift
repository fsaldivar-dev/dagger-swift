//
//  RepoDetailViewModel.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · MVVM ViewModel (Scoped)
//  Gobierna el ciclo de vida del detalle en el submódulo `RepoDetailModule`.
//

import Foundation
import SwiftUI
import DaggerSwift

@MainActor
public final class RepoDetailViewModel: ObservableObject {
    public let inspector: RepoDetailInspector
    public let scope: ScopeContainer

    public init(session: ActiveRepoSession) {
        self.inspector = session.inspector
        self.scope = session.scope
    }

    public var repo: GitHubRepoItem {
        inspector.repo
    }

    public var instanceID: String {
        inspector.instanceID
    }

    public var activeObjectsInScope: Int {
        scope.activeInstanceCount
    }

    public var environmentDescription: String {
        inspector.serviceEnvironment
    }
}
