//
//  ShowcaseCoreModule.swift
//  SampleProyect
//
//  Clean Architecture · DI · Core Module
//  Declara los Singletons de Dominio y Datos, Casos de Uso, Nodos de Regla de Negocio
//  (@BusinessRule) y Nodos de Precondición (@Precondition ValidatedSession).
//

import Foundation
import DaggerSwift

// MARK: - Estrategias de Regla de Negocio (Layout Explorer)

public final class ClassicRepoExplorerStrategy: RepoExplorerStrategyProtocol {
    public let variant: ExplorerLayoutVariant = .classicV1
    public let badgeTitle: String = "RAMA A · CLÁSICO"
    public let accentDescription: String = "Renderizado compacto tradicional inyectado cuando el Feature Flag está apagado."
    public let showsArchitectureTelemetry: Bool = false
    public let usesBentoGrid: Bool = false
    public let repository: any GitHubRepositoryProtocol

    public init(repository: any GitHubRepositoryProtocol) {
        self.repository = repository
    }
}

public final class BentoRepoExplorerStrategy: RepoExplorerStrategyProtocol {
    public let variant: ExplorerLayoutVariant = .bentoV2
    public let badgeTitle: String = "RAMA B · BENTO DAG V2"
    public let accentDescription: String = "Tarjetas enriquecidas con métricas de arquitectura, licencias y árbol de archivos inyectadas por Regla de Negocio."
    public let showsArchitectureTelemetry: Bool = true
    public let usesBentoGrid: Bool = true
    public let repository: any GitHubRepositoryProtocol
    public let manifestoRepo: any ManifestoRepositoryProtocol

    public init(repository: any GitHubRepositoryProtocol, manifestoRepo: any ManifestoRepositoryProtocol) {
        self.repository = repository
        self.manifestoRepo = manifestoRepo
    }
}

// MARK: - Showcase Core Module

@Module
public enum ShowcaseCoreModule {

    // Repositorios de datos
    @Singleton
    public static func manifestoRepository() -> any ManifestoRepositoryProtocol {
        ManifestoLocalRepository()
    }

    @Singleton
    public static func authRepository() -> any AuthRepositoryProtocol {
        AuthSessionRepository()
    }

    @Singleton
    public static func featureFlags() -> any FeatureFlagRepositoryProtocol {
        FeatureFlagRepositoryImpl()
    }

    // Casos de Uso (Clean Architecture Domain UseCases)
    @Singleton
    public static func getProfileUseCase(repo: any GitHubRepositoryProtocol) -> GetProfileUseCase {
        GetProfileUseCase(gitHubRepository: repo)
    }

    @Singleton
    public static func getRepositoriesUseCase(repo: any GitHubRepositoryProtocol) -> GetRepositoriesUseCase {
        GetRepositoriesUseCase(gitHubRepository: repo)
    }

    @Singleton
    public static func getManifestoChaptersUseCase(repo: any ManifestoRepositoryProtocol) -> GetManifestoChaptersUseCase {
        GetManifestoChaptersUseCase(manifestoRepository: repo)
    }

    @Singleton
    public static func authenticateUseCase(authRepo: any AuthRepositoryProtocol) -> AuthenticateUseCase {
        AuthenticateUseCase(authRepository: authRepo)
    }

    @Singleton
    public static func logoutUseCase(authRepo: any AuthRepositoryProtocol) -> LogoutUseCase {
        LogoutUseCase(authRepository: authRepo)
    }

    @Singleton
    public static func toggleExplorerVariantUseCase(flags: any FeatureFlagRepositoryProtocol) -> ToggleExplorerVariantUseCase {
        ToggleExplorerVariantUseCase(featureFlagRepository: flags)
    }

    // Regla de Negocio dinámica (@BusinessRule A -> B)
    @BusinessRule
    public static func explorerStrategy(
        flags: any FeatureFlagRepositoryProtocol,
        repository: any GitHubRepositoryProtocol,
        manifesto: any ManifestoRepositoryProtocol
    ) -> any RepoExplorerStrategyProtocol {
        if flags.isBentoV2Enabled {
            return BentoRepoExplorerStrategy(repository: repository, manifestoRepo: manifesto)
        }
        return ClassicRepoExplorerStrategy(repository: repository)
    }

    // Precondición (@Precondition: ValidatedSession)
    @Precondition("Se requiere sesión activa de @fsaldivar-dev para acceder a submódulos protegidos")
    public static func validatedSession(auth: any AuthRepositoryProtocol) -> ValidatedSession? {
        auth.currentSession
    }
}
