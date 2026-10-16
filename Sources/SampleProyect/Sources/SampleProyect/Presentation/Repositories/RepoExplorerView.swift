//
//  RepoExplorerView.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Feature View
//  Explorador interactivo de repositorios que conmuta en tiempo real entre la Rama A (Clásica)
//  y la Rama B (Bento) según el nodo `@BusinessRule`.
//

import SwiftUI

public struct RepoExplorerView: View {
    @ObservedObject public var viewModel: RepoExplorerViewModel
    @ObservedObject public var coordinator: ShowcaseCoordinator

    public init(viewModel: RepoExplorerViewModel, coordinator: ShowcaseCoordinator) {
        self.viewModel = viewModel
        self.coordinator = coordinator
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Banner de Regla de Negocio
                businessRuleBanner

                // Barra de Búsqueda
                searchBar

                if viewModel.isLoading {
                    ProgressView("Consultando repositorios de @fsaldivar-dev...")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                }

                // Renderizado condicionado por la estrategia inyectada
                if viewModel.currentStrategy.usesBentoGrid {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 290, maximum: 520), spacing: 12)],
                        spacing: 12
                    ) {
                        ForEach(viewModel.filteredRepositories) { repo in
                            RepoBentoCardView(repo: repo) {
                                coordinator.openRepository(repo)
                            }
                        }
                    }
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.filteredRepositories) { repo in
                            RepoClassicRowView(repo: repo) {
                                coordinator.openRepository(repo)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .task {
            await viewModel.loadRepositories()
        }
    }

    private var businessRuleBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.purple.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.purple)
                    .font(.subheadline.bold())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.currentStrategy.badgeTitle)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.primary)

                Text(viewModel.currentStrategy.accentDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { viewModel.currentStrategy.usesBentoGrid },
                set: { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        viewModel.toggleStrategy(coordinator: coordinator)
                    }
                }
            ))
            .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.purple.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Buscar repositorios de @fsaldivar-dev...", text: $viewModel.searchText)
                .font(.subheadline)
                .textFieldStyle(.plain)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
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
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
