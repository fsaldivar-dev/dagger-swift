//
//  LiveGitHubModule.swift
//  SampleProyect
//
//  Clean Architecture · DI · Module (Target: Demo)
//  Provee la implementación real de GitHub conectada al REST API.
//

import Foundation
import DaggerSwift

@Module
public enum LiveGitHubModule {
    @Singleton
    public static func gitHubRepository() -> any GitHubRepositoryProtocol {
        LiveGitHubRepository()
    }
}
