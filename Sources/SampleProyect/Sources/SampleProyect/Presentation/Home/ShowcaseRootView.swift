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

    public init(assembler: DaggerShowcaseAssembler) {
        let coord = ShowcaseCoordinator(assembler: assembler)
        _coordinator = StateObject(wrappedValue: coord)
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(container: assembler.rootContainer))
        _repoExplorerViewModel = StateObject(wrappedValue: RepoExplorerViewModel(container: assembler.rootContainer))
        _deepLinksViewModel = StateObject(wrappedValue: DeepLinksViewModel(container: assembler.rootContainer))
        _manifestoViewModel = StateObject(wrappedValue: ManifestoViewModel(container: assembler.rootContainer))
        _scopeMonitorViewModel = StateObject(wrappedValue: ScopeMonitorViewModel(assembler: assembler))
    }

    public init(environment: any GraphModule.Type = LiveGitHubModule.self) {
        let assembler = DaggerShowcaseAssembler(environment: environment)
        let coord = ShowcaseCoordinator(assembler: assembler)
        _coordinator = StateObject(wrappedValue: coord)
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(container: assembler.rootContainer))
        _repoExplorerViewModel = StateObject(wrappedValue: RepoExplorerViewModel(container: assembler.rootContainer))
        _deepLinksViewModel = StateObject(wrappedValue: DeepLinksViewModel(container: assembler.rootContainer))
        _manifestoViewModel = StateObject(wrappedValue: ManifestoViewModel(container: assembler.rootContainer))
        _scopeMonitorViewModel = StateObject(wrappedValue: ScopeMonitorViewModel(assembler: assembler))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Banner: Perfil (@fsaldivar-dev) y Botón de Autenticación
                profileHeaderBanner

                // Selector de pestañas
                Picker("Sección", selection: $coordinator.selectedTab) {
                    ForEach(ShowcaseTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.systemIcon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

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
                        Label("Actualizar", systemImage: "arrow.clockwise")
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

    // MARK: - Banner de Perfil y Chips de Estado

    private var profileHeaderBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
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
                                        colors: [.indigo, .purple, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 2))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(homeViewModel.profile.name)
                            .font(.headline.bold())
                        Text("@\(homeViewModel.profile.login)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(homeViewModel.profile.bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Label("\(homeViewModel.profile.publicRepos) repos", systemImage: "folder.fill")
                        Label("\(homeViewModel.profile.followers) followers", systemImage: "person.2.fill")
                        Label(homeViewModel.profile.location, systemImage: "location.fill")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Botón de Precondición
                Button {
                    homeViewModel.toggleAuthentication(coordinator: coordinator)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: homeViewModel.isAuthenticated ? "checkmark.shield.fill" : "lock.slash.fill")
                        Text(homeViewModel.isAuthenticated ? "Sesión Activa" : "Sin Sesión")
                            .font(.caption.bold())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(homeViewModel.isAuthenticated ? Color.green.opacity(0.18) : Color.orange.opacity(0.18))
                    )
                    .foregroundStyle(homeViewModel.isAuthenticated ? Color.green : Color.orange)
                }
                .buttonStyle(.plain)
            }

            // Chips informativos
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    statusChip(icon: "cpu.fill", text: homeViewModel.environmentTitle, tint: .blue)

                    Button {
                        homeViewModel.toggleLayoutVariant(coordinator: coordinator)
                        repoExplorerViewModel.refreshStrategy()
                    } label: {
                        statusChip(
                            icon: "flag.2.crossed.fill",
                            text: repoExplorerViewModel.currentStrategy.badgeTitle + " (Tocar)",
                            tint: repoExplorerViewModel.currentStrategy.usesBentoGrid ? .purple : .gray
                        )
                    }
                    .buttonStyle(.plain)

                    statusChip(
                        icon: "memorychip.fill",
                        text: "Scopes Creados: \(coordinator.totalScopesCreated) · Liberados: \(coordinator.totalScopesTornDown) · Leaks: \(coordinator.lastLeakAuditCount)",
                        tint: .teal
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(Color.secondary.opacity(0.06))
    }

    private func statusChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
        .foregroundStyle(tint)
    }
}

// Retro-compatibilidad total
public typealias DaggerShowcaseRootView = ShowcaseRootView
