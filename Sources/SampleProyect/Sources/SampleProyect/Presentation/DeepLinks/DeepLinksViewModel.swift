//
//  DeepLinksViewModel.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · MVVM ViewModel
//  Gobierna el laboratorio de simulación de Deep Links y precondiciones de seguridad.
//

import Foundation
import SwiftUI
import DaggerSwift

@MainActor
@Inject
public final class DeepLinksViewModel: ObservableObject {
    private let authRepository: any AuthRepositoryProtocol
    private let authenticateUseCase: AuthenticateUseCase
    private let logoutUseCase: LogoutUseCase

    @Published public var presets: [ShowcaseDeepLink] = [
        .privateVault,
        .repoDetail(name: "dagger-swift", requiresAuth: true),
        .repoDetail(name: "AutoPilot", requiresAuth: false),
        .repoDetail(name: "codaru-mockup", requiresAuth: false),
        .manifesto(chapterID: "aaron-swartz"),
        .manifesto(chapterID: "memoria-v1-v2"),
        .featureFlag(enableBentoV2: true)
    ]

    public init(
        authRepository: any AuthRepositoryProtocol,
        authenticateUseCase: AuthenticateUseCase,
        logoutUseCase: LogoutUseCase
    ) {
        self.authRepository = authRepository
        self.authenticateUseCase = authenticateUseCase
        self.logoutUseCase = logoutUseCase
    }

    public var isAuthenticated: Bool {
        authRepository.isAuthenticated
    }

    public var currentUsername: String? {
        authRepository.currentSession?.username
    }

    public func login(coordinator: ShowcaseCoordinator) {
        let session = authenticateUseCase.execute()
        coordinator.appendLog(
            category: "Precondition",
            message: "✅ Sesión autenticada como @\(session.username). Nodo `ValidatedSession` emitido."
        )
        coordinator.onAuthenticatedSuccess()
    }

    public func logout(coordinator: ShowcaseCoordinator) {
        coordinator.closeActiveRepoDetail()
        coordinator.closePrivateVault()
        logoutUseCase.execute()
        coordinator.appendLog(
            category: "Precondition",
            message: "🔒 Sesión revocada. Nodo `ValidatedSession` destruido."
        )
    }
}
