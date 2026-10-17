//
//  FeedView.swift
//  Features
//
//  Capa Features · Pantalla Principal de Perfil Social y Feed de Repositorios.
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

    public init<M: GitHubServiceModuleContract>(module: M.Type) {
        self._viewModel = StateObject(wrappedValue: FeedViewModel.plug(module))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
                    Button { Task { await viewModel.refresh() } } label: {
                        Image(systemName: "arrow.clockwise").font(.subheadline.bold())
                    }
                }
            }
        }
        .task { await viewModel.loadInitialData() }
        .sheet(item: $viewModel.activeRepoSession, onDismiss: { viewModel.closeActiveRepoDetail() }) { session in
            RepoDetailView(session: session) { viewModel.closeActiveRepoDetail() }
        }
        .sheet(isPresented: $viewModel.showAuthGateSheet) {
            AuthPreconditionGateSheet(
                reason: viewModel.blockedReason ?? "Se requiere sesión activa (@Precondition ValidatedSession)",
                onAuthenticate: { viewModel.login() },
                onCancel: { viewModel.showAuthGateSheet = false }
            )
        }
    }

    private var socialProfileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle()
                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(viewModel.profile.name).font(.title3.weight(.bold))
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
                    }
                    Text("@\(viewModel.profile.login)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.snappy) { viewModel.toggleAuthentication() }
                } label: {
                    Label(
                        viewModel.isAuthenticated ? "Sesión Activa" : "Iniciar Sesión",
                        systemImage: viewModel.isAuthenticated ? "checkmark.shield.fill" : "lock.shield"
                    )
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(viewModel.isAuthenticated ? Color.green.opacity(0.15) : Color.primary.opacity(0.08)))
                    .foregroundStyle(viewModel.isAuthenticated ? Color.green : Color.primary)
                }
                .buttonStyle(.plain)
            }
            if !viewModel.profile.bio.isEmpty {
                Text(viewModel.profile.bio).font(.subheadline).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Label(viewModel.environmentTitle, systemImage: "network")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
                Spacer()
                Label("Scopes: \(viewModel.totalScopesCreated) · Leaks: \(viewModel.lastLeakAuditCount)", systemImage: "memorychip")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.showcaseCardBackground))
    }

    private var businessRuleSwitchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.branch").foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text("@BusinessRule · \(viewModel.currentStrategy.badgeTitle)").font(.footnote.weight(.bold))
                Text(viewModel.currentStrategy.accentDescription).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { viewModel.currentStrategy.usesBentoGrid },
                set: { _ in withAnimation(.snappy) { viewModel.toggleStrategy() } }
            ))
            .labelsHidden()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.purple.opacity(0.08)))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Filtrar repositorios...", text: $viewModel.searchText)
                .font(.subheadline)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.showcaseSubtleFill))
    }

    private var repositoryListSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredRepositories) { repo in
                if viewModel.currentStrategy.usesBentoGrid {
                    RepoBentoCardView(repo: repo) { viewModel.openRepository(repo) }
                } else {
                    RepoClassicRowView(repo: repo) { viewModel.openRepository(repo) }
                }
            }
        }
    }
}
