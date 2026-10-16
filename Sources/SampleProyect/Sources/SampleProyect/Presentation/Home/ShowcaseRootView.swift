//
//  ShowcaseRootView.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Root MVVM View
//  Punto de entrada de UI multiplataforma (iOS, iPadOS, macOS).
//  Integra los ViewModels de cada módulo con Clean Architecture y DaggerSwift v2.
//

import SwiftUI
import DaggerSwift

public struct ShowcaseRootView: View {
    @StateObject private var coordinator: ShowcaseCoordinator
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var repoExplorerViewModel: RepoExplorerViewModel
    @StateObject private var deepLinksViewModel: DeepLinksViewModel
    @StateObject private var manifestoViewModel: ManifestoViewModel
    @StateObject private var scopeMonitorViewModel: ScopeMonitorViewModel

    public init(container: ScopeContainer) throws {
        let coordinator = ShowcaseCoordinator(container: container)
        let homeViewModel = try HomeViewModel(from: container)
        let repoExplorerViewModel = try RepoExplorerViewModel(from: container)
        let deepLinksViewModel = try DeepLinksViewModel(from: container)
        let manifestoViewModel = try ManifestoViewModel(from: container)
        let scopeMonitorViewModel = try ScopeMonitorViewModel(from: container)

        _coordinator = StateObject(wrappedValue: coordinator)
        _homeViewModel = StateObject(wrappedValue: homeViewModel)
        _repoExplorerViewModel = StateObject(wrappedValue: repoExplorerViewModel)
        _deepLinksViewModel = StateObject(wrappedValue: deepLinksViewModel)
        _manifestoViewModel = StateObject(wrappedValue: manifestoViewModel)
        _scopeMonitorViewModel = StateObject(wrappedValue: scopeMonitorViewModel)
    }

    public init(environment: any GraphModule.Type = LiveGitHubModule.self) {
        let container = ShowcaseCoreModule.buildGraph(including: [environment])
        try! self.init(container: container)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Banner: Perfil Social (@fsaldivar-dev)
                socialProfileHeader

                // Barra de Pestañas Social (Sliding Capsule Tab Bar)
                socialTabBar

                Divider()

                // Pantalla activa gobernada por MVVM
                Group {
                    switch coordinator.selectedTab {
                    case .repositories:
                        RepoExplorerView(
                            viewModel: repoExplorerViewModel,
                            coordinator: coordinator
                        )
                    case .deepLinks:
                        DeepLinksLabView(
                            viewModel: deepLinksViewModel,
                            coordinator: coordinator
                        )
                    case .manifesto:
                        ManifestoView(
                            viewModel: manifestoViewModel
                        )
                    case .graphMonitor:
                        ScopeMonitorView(
                            viewModel: scopeMonitorViewModel,
                            coordinator: coordinator
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task {
                            await homeViewModel.loadProfile()
                            await repoExplorerViewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .task {
            await homeViewModel.loadProfile()
        }
        .onOpenURL { url in
            coordinator.handleDeepLinkURL(url)
        }
        // Sheets Scoped de Módulos (RepoDetail y PrivateVault)
        .sheet(item: $coordinator.activeRepoSession, onDismiss: {
            coordinator.closeActiveRepoDetail()
        }) { session in
            RepoDetailView(session: session) {
                coordinator.closeActiveRepoDetail()
            }
        }
        .sheet(item: $coordinator.activeVaultSession, onDismiss: {
            coordinator.closePrivateVault()
        }) { vaultSession in
            PrivateVaultView(session: vaultSession) {
                coordinator.closePrivateVault()
            }
        }
        // Sheet de Precondición No Cumplida (Auth Gate)
        .sheet(isPresented: $coordinator.showAuthGateSheet) {
            AuthPreconditionGateSheet(
                reason: coordinator.blockedPreconditionReason ?? "Ruta protegida por ValidatedSession",
                pendingDeepLink: coordinator.pendingDeepLink,
                onAuthenticate: {
                    homeViewModel.login(coordinator: coordinator)
                },
                onCancel: {
                    coordinator.showAuthGateSheet = false
                    coordinator.pendingDeepLink = nil
                }
            )
        }
    }

    // MARK: - Perfil Estilo Social (GitHub Mobile / Threads)

    private var socialProfileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Fila superior: Avatar + Botón de Estado / Autenticación
            HStack(alignment: .center) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: homeViewModel.profile.avatarURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.indigo, .purple, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 2))
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)

                    // Dot indicador de estado
                    Circle()
                        .fill(homeViewModel.isAuthenticated ? Color.green : Color.orange)
                        .frame(width: 15, height: 15)
                        .overlay(Circle().stroke(Color.showcaseSystemBackground, lineWidth: 2.5))
                        .offset(x: -1, y: -1)
                }

                Spacer()

                // Botón de acción social
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        homeViewModel.toggleAuthentication(coordinator: coordinator)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: homeViewModel.isAuthenticated ? "checkmark.shield.fill" : "lock.shield")
                            .font(.caption.bold())
                        Text(homeViewModel.isAuthenticated ? "Sesión Activa" : "Iniciar Sesión")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(homeViewModel.isAuthenticated ? Color.green.opacity(0.14) : Color.primary.opacity(0.06))
                    )
                    .overlay(
                        Capsule().stroke(homeViewModel.isAuthenticated ? Color.green.opacity(0.4) : Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .foregroundStyle(homeViewModel.isAuthenticated ? Color.green : Color.primary)
                }
                .buttonStyle(.plain)
            }

            // Nombre y Usuario
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(homeViewModel.profile.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }

                Text("@\(homeViewModel.profile.login)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Biografía completa
            if !homeViewModel.profile.bio.isEmpty {
                Text(homeViewModel.profile.bio)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.9))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Metadata: Ubicación y Stack
            HStack(spacing: 14) {
                if !homeViewModel.profile.location.isEmpty {
                    Label(homeViewModel.profile.location, systemImage: "mappin.and.ellipse")
                }
                Label("Swift 6 · Dagger DAG", systemImage: "cpu")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Contadores sociales (GitHub / Twitter metrics)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("\(homeViewModel.profile.publicRepos)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("repos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text("\(homeViewModel.profile.followers)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("seguidores")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Text("\(homeViewModel.profile.following)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("siguiendo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Barra de Estado de Arquitectura
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                        Text(homeViewModel.environmentTitle)
                            .font(.caption2.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.blue.opacity(0.12)))
                    .foregroundStyle(.blue)

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            homeViewModel.toggleLayoutVariant(coordinator: coordinator)
                            repoExplorerViewModel.refreshStrategy()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "rectangle.3.group")
                            Text(repoExplorerViewModel.currentStrategy.badgeTitle)
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(repoExplorerViewModel.currentStrategy.usesBentoGrid ? Color.purple.opacity(0.14) : Color.secondary.opacity(0.12))
                        )
                        .foregroundStyle(repoExplorerViewModel.currentStrategy.usesBentoGrid ? Color.purple : Color.secondary)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 5) {
                        Image(systemName: "memorychip.fill")
                        Text("Scopes: \(coordinator.totalScopesCreated) · Liberados: \(coordinator.totalScopesTornDown) · Leaks: \(coordinator.lastLeakAuditCount)")
                    }
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.teal.opacity(0.12)))
                    .foregroundStyle(.teal)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color.showcaseHeaderBackground)
    }

    // MARK: - Barra de Pestañas Social (Capsule Tabs)

    private var socialTabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ShowcaseTab.allCases, id: \.self) { tab in
                    let isSelected = coordinator.selectedTab == tab
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            coordinator.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemIcon)
                                .font(.caption.weight(.semibold))
                            Text(tab.rawValue)
                                .font(.subheadline.weight(isSelected ? .bold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.primary : Color.secondary.opacity(0.1))
                        )
                        .foregroundStyle(isSelected ? Color.showcaseSystemBackground : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// Retro-compatibilidad total
public typealias DaggerShowcaseRootView = ShowcaseRootView
