//
//  FeedView.swift
//  Features
//
//  Capa Features · Pantalla Principal de Perfil Social y Feed de Repositorios.
//  Enfocada únicamente en el flujo esencial: Perfil + Lista de Repos + Detalle Scoped.
//

import SwiftUI
import DaggerSwift
import AppFoundation
import Core

public struct FeedView: View {
    @StateObject private var viewModel: FeedViewModel

    public init(viewModel: FeedViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    socialProfileCard

                    businessRuleSwitchBar

                    searchBar

                    repositoryListSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Developer Feed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.bold())
                    }
                }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
        .sheet(item: $viewModel.activeRepoSession, onDismiss: {
            viewModel.closeActiveRepoDetail()
        }) { session in
            RepoDetailView(session: session) {
                viewModel.closeActiveRepoDetail()
            }
        }
        .sheet(isPresented: $viewModel.showAuthGateSheet) {
            AuthPreconditionGateSheet(
                reason: viewModel.blockedReason ?? "Se requiere sesión activa (@Precondition ValidatedSession)",
                onAuthenticate: { viewModel.login() },
                onCancel: { viewModel.showAuthGateSheet = false }
            )
        }
    }

    // MARK: - 1. Tarjeta Social de Perfil (@fsaldivar-dev)

    private var socialProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: viewModel.profile.avatarURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Circle()
                                .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                )
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1.5))

                    Circle()
                        .fill(viewModel.isAuthenticated ? Color.green : Color.orange)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.showcaseCardBackground, lineWidth: 2.5))
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.toggleAuthentication()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isAuthenticated ? "checkmark.shield.fill" : "lock.shield")
                            .font(.caption.bold())
                        Text(viewModel.isAuthenticated ? "Sesión Activa" : "Iniciar Sesión")
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(viewModel.isAuthenticated ? Color.green.opacity(0.15) : Color.primary.opacity(0.07))
                    )
                    .foregroundStyle(viewModel.isAuthenticated ? Color.green : Color.primary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(viewModel.profile.name)
                        .font(.title3.weight(.bold))
                    Image(systemName: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
                Text("@\(viewModel.profile.login)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !viewModel.profile.bio.isEmpty {
                Text(viewModel.profile.bio)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Métricas sociales
            HStack(spacing: 16) {
                metricLabel(count: viewModel.profile.publicRepos, label: "repos")
                metricLabel(count: viewModel.profile.followers, label: "seguidores")
                metricLabel(count: viewModel.profile.following, label: "siguiendo")
                if !viewModel.profile.location.isEmpty {
                    Label(viewModel.profile.location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Telemetría compacta del Grafo DaggerSwift
            HStack(spacing: 8) {
                Label(viewModel.environmentTitle, systemImage: "network")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.blue.opacity(0.12)))
                    .foregroundStyle(.blue)

                Spacer()

                Label("Scopes: \(viewModel.totalScopesCreated) · Leaks: \(viewModel.lastLeakAuditCount)", systemImage: "memorychip")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.showcaseCardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }

    private func metricLabel(count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.subheadline.weight(.bold))
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 2. Control de @BusinessRule (Bento v2 vs Compacto v1)

    private var businessRuleSwitchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(.purple)
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 2) {
                Text("@BusinessRule · \(viewModel.currentStrategy.badgeTitle)")
                    .font(.footnote.weight(.bold))
                Text(viewModel.currentStrategy.accentDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.currentStrategy.usesBentoGrid },
                set: { _ in
                    withAnimation(.snappy(duration: 0.25)) {
                        viewModel.toggleStrategy()
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.purple.opacity(0.07))
        )
    }

    // MARK: - 3. Buscador Spotlight

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Filtrar repositorios...", text: $viewModel.searchText)
                .font(.subheadline)
                .textFieldStyle(.plain)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.showcaseSubtleFill)
        )
    }

    // MARK: - 4. Lista de Repositorios

    private var repositoryListSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredRepositories) { repo in
                if viewModel.currentStrategy.usesBentoGrid {
                    RepoBentoCardView(repo: repo) {
                        viewModel.openRepository(repo)
                    }
                } else {
                    RepoClassicRowView(repo: repo) {
                        viewModel.openRepository(repo)
                    }
                }
            }
        }
    }
}
