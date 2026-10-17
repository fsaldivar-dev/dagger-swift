//
//  ServiceModules.swift
//  Services
//
//  Capa Services · Módulos de Producción (sin Fakes en Release).
//  Demuestra cómo `LiveGitHubModuleV2` hereda `gitHubRepository()` y `featureFlags()`
//  de `LiveGitHubModule` usando `@Module(2.0, includes: [LiveGitHubModule.self])`
//  y SOLO implementa el proveedor que cambió (`authRepository()`).
//

import Foundation
import DaggerSwift
import Core

/// Versión 1.0 (Base) del módulo de Servicios de Producción.
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

public extension GitHubServiceModuleContract {
    static func gitHubRepository() -> any GitHubRepositoryProtocol {
        LiveGitHubModule.gitHubRepository()
    }

    static func authRepository() -> any AuthRepositoryProtocol {
        LiveGitHubModule.authRepository()
    }

    static func featureFlags() -> any FeatureFlagRepositoryProtocol {
        LiveGitHubModule.featureFlags()
    }
}

/// Versión 2.0 del módulo de Servicios:
/// Hereda `gitHubRepository()` y `featureFlags()` de `LiveGitHubModule`
/// y SOLO implementa el flujo de autenticación nuevo (`AuthSessionRepositoryV2`).
@Module(2.0, includes: [LiveGitHubModule.self])
public enum LiveGitHubModuleV2: GitHubServiceModuleContract {
    @Singleton
    public static func authRepository() -> any AuthRepositoryProtocol {
        AuthSessionRepositoryV2()
    }
}
