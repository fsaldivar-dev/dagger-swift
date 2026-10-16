//
//  ServiceModules.swift
//  Services
//
//  Capa Services · Módulos @Module intercambiables para Producción (Live) y Sandbox (Faker).
//

import Foundation
import DaggerSwift
import Core

@Module
public enum LiveGitHubModule {
    @Singleton
    public static func gitHubRepository() -> any GitHubRepositoryProtocol {
        LiveGitHubRepository()
    }

    @Singleton
    public static func authRepository() -> any AuthRepositoryProtocol {
        AuthSessionRepository()
    }

    @Singleton
    public static func featureFlags() -> any FeatureFlagRepositoryProtocol {
        FeatureFlagRepositoryImpl()
    }
}

@Module
public enum FakerGitHubModule {
    @Singleton
    public static func gitHubRepository() -> any GitHubRepositoryProtocol {
        FakerGitHubRepository()
    }

    @Singleton
    public static func authRepository() -> any AuthRepositoryProtocol {
        AuthSessionRepository()
    }

    @Singleton
    public static func featureFlags() -> any FeatureFlagRepositoryProtocol {
        FeatureFlagRepositoryImpl()
    }
}
