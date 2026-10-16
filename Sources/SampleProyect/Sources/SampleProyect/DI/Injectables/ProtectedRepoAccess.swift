//
//  ProtectedRepoAccess.swift
//  SampleProyect
//
//  Clean Architecture · DI / Protected Node
//  Acceso a un repositorio protegido. El parámetro `session: ValidatedSession` va primero:
//  si la precondición no se cumple, el grafo DAG aborta la resolución antes de instanciar nada.
//

import Foundation
import DaggerSwift

@Inject
public final class ProtectedRepoAccess {
    public let session: ValidatedSession
    public let inspector: RepoDetailInspector

    public init(session: ValidatedSession, inspector: RepoDetailInspector) {
        self.session = session
        self.inspector = inspector
    }
}
