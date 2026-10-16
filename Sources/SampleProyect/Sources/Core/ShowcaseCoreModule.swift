//
//  ShowcaseCoreModule.swift
//  Core
//
//  Capa Core · Módulo Raíz de Dominio (@Module).
//  Solo declara la Regla de Negocio (@BusinessRule) y la Precondición (@Precondition).
//  Los Casos de Uso y ViewModels con @Inject se auto-resuelven sin registrarse aquí.
//

import Foundation
import DaggerSwift
import AppFoundation

@Module
public enum ShowcaseCoreModule {

    @BusinessRule
    public static func explorerStrategy(
        flags: any FeatureFlagRepositoryProtocol
    ) -> any RepoExplorerStrategyProtocol {
        flags.isBentoV2Enabled ? RepoExplorerStrategy.bento : RepoExplorerStrategy.classic
    }

    @Precondition("Se requiere sesión activa de @fsaldivar-dev para inspeccionar módulos protegidos")
    public static func validatedSession(
        auth: any AuthRepositoryProtocol
    ) -> ValidatedSession? {
        auth.currentSession
    }
}
