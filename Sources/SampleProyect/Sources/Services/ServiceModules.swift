//
//  ServiceModules.swift
//  Services
//
//  Capa Services · Módulos de Producción (sin Fakes en Release).
//  Demuestra cómo `LiveGitHubModuleV2` conserva los providers de Network y FeatureFlags
//  de `LiveGitHubModule` usando `@Module(includes:)` y solo reemplaza el flujo de Login por V2.
//

import Foundation
import DaggerSwift
import Core

/// Versión 1.0 del módulo de Servicios de Producción.
@Module(1.0)
public enum LiveGitHubModule: GitHubServiceModuleContract {
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

/// Versión 2.0 del módulo de Servicios:
/// Conserva `gitHubRepository()` y `featureFlags()` de `LiveGitHubModule`,
/// y reemplaza únicamente el flujo de autenticación por `AuthSessionRepositoryV2`.
@Module(2.0, includes: [LiveGitHubModule.self])
public enum LiveGitHubModuleV2 {
    @Singleton
    public static func authRepository() -> any AuthRepositoryProtocol {
        AuthSessionRepositoryV2()
    }
}

extension LiveGitHubModuleV2: GitHubServiceModuleContract {
    public static func gitHubRepository() -> any GitHubRepositoryProtocol {
        LiveGitHubModule.gitHubRepository()
    }

    public static func featureFlags() -> any FeatureFlagRepositoryProtocol {
        LiveGitHubModule.featureFlags()
    }
}
