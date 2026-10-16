//
//  HomeViewModel.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · MVVM ViewModel
//  Gobierna el encabezado principal, el perfil de usuario y la simulación de autenticación (Precondition).
//

import Foundation
import SwiftUI
import DaggerSwift

@MainActor
public final class HomeViewModel: ObservableObject {
    private let getProfileUseCase: GetProfileUseCase
    private let authenticateUseCase: AuthenticateUseCase
    private let logoutUseCase: LogoutUseCase
    private let authRepository: any AuthRepositoryProtocol
    private let toggleVariantUseCase: ToggleExplorerVariantUseCase
    private let gitHubRepository: any GitHubRepositoryProtocol

    @Published public var profile: GitHubUserProfile = .fsaldivarDefault
    @Published public var isAuthenticated: Bool = false
    @Published public var currentSession: ValidatedSession?
    @Published public var isBentoV2Enabled: Bool = true
    @Published public var isLoading: Bool = false

    public init(container: ScopeContainer) {
        self.getProfileUseCase = try! container.resolve(GetProfileUseCase.self)
        self.authenticateUseCase = try! container.resolve(AuthenticateUseCase.self)
        self.logoutUseCase = try! container.resolve(LogoutUseCase.self)
        self.authRepository = try! container.resolve((any AuthRepositoryProtocol).self)
        self.toggleVariantUseCase = try! container.resolve(ToggleExplorerVariantUseCase.self)
        self.gitHubRepository = try! container.resolve((any GitHubRepositoryProtocol).self)

        self.isAuthenticated = authRepository.isAuthenticated
        self.currentSession = authRepository.currentSession
        self.isBentoV2Enabled = toggleVariantUseCase.isBentoV2Enabled
    }

    public var environmentTitle: String {
        gitHubRepository.environmentTitle
    }

    public func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.profile = try await getProfileUseCase.execute()
        } catch {
            self.profile = .fsaldivarDefault
        }
    }

    public func toggleAuthentication(coordinator: ShowcaseCoordinator) {
        if isAuthenticated {
            logout(coordinator: coordinator)
        } else {
            login(coordinator: coordinator)
        }
    }

    public func login(coordinator: ShowcaseCoordinator) {
        let session = authenticateUseCase.execute()
        self.isAuthenticated = true
        self.currentSession = session
        coordinator.appendLog(
            category: "Precondition",
            message: "✅ Sesión iniciada como @\(session.username). El nodo `ValidatedSession` está disponible en el grafo."
        )
        coordinator.onAuthenticatedSuccess()
    }

    public func logout(coordinator: ShowcaseCoordinator) {
        coordinator.closeActiveRepoDetail()
        coordinator.closePrivateVault()
        logoutUseCase.execute()
        self.isAuthenticated = false
        self.currentSession = nil
        coordinator.appendLog(
            category: "Precondition",
            message: "🔒 Sesión cerrada. El nodo `ValidatedSession` fue removido y los scopes protegidos liberaron su RAM."
        )
    }

    public func toggleLayoutVariant(coordinator: ShowcaseCoordinator) {
        let newValue = !isBentoV2Enabled
        toggleVariantUseCase.execute(enableBentoV2: newValue)
        self.isBentoV2Enabled = newValue
        coordinator.appendLog(
            category: "BusinessRule",
            message: "Feature flag Bento v2 actualizado a: \(newValue)."
        )
    }
}
