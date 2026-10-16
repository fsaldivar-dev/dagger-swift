//
//  FakerGitHubModule.swift
//  SampleProyect
//
//  Clean Architecture · DI · Module (Target: DemoFaker)
//  Provee la implementación sandbox determinista offline.
//

import Foundation
import DaggerSwift

@Module
public enum FakerGitHubModule {
    @Singleton
    public static func gitHubRepository() -> any GitHubRepositoryProtocol {
        FakerGitHubRepository()
    }
}
