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
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(.purple)
                    Text("Nodo de Regla de Negocio: \(viewModel.currentStrategy.variant.rawValue)")
                        .font(.subheadline.bold())
                }
                Text(viewModel.currentStrategy.accentDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Bento v2", isOn: Binding(
                get: { viewModel.currentStrategy.usesBentoGrid },
                set: { _ in viewModel.toggleStrategy(coordinator: coordinator) }
            ))
            .labelsHidden()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.08))
        )
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar repositorio en @fsaldivar-dev (ej. dagger-swift, AutoPilot, Kairo)...", text: $viewModel.searchText)
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}
