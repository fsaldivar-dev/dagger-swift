//
//  RepoDetailView.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Scoped Feature View
//  Presenta los detalles de un repositorio ejecutando `teardown()` determinista al cerrarse.
//

import SwiftUI

public struct RepoDetailView: View {
    @StateObject private var viewModel: RepoDetailViewModel
    public let onClose: () -> Void

    public init(session: ActiveRepoSession, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: RepoDetailViewModel(session: session))
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Telemetría del Scope en RAM
                    scopeMemoryBanner

                    Text(viewModel.repo.fullName)
                        .font(.title2.bold())

                    Text(viewModel.repo.description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        Label("\(viewModel.repo.stars) Stars", systemImage: "star.fill")
                        Label("\(viewModel.repo.forks) Forks", systemImage: "tuningfork")
                        Label(viewModel.repo.language, systemImage: "chevron.left.forwardslash.chevron.right")
                        Label("\(viewModel.repo.sizeKB) KB", systemImage: "externaldrive.fill")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)

                    if !viewModel.repo.architectureNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notas de Arquitectura")
                                .font(.headline)
                            Text(viewModel.repo.architectureNotes)
                                .font(.callout)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
                    }

                    if !viewModel.repo.sampleFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Árbol de Archivos Destacados")
                                .font(.headline)
                            ForEach(viewModel.repo.sampleFiles, id: \.self) { file in
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundStyle(.indigo)
                                    Text(file)
                                        .font(.caption.monospaced())
                                    Spacer()
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
                            }
                        }
                    }

                    if let url = URL(string: viewModel.repo.htmlURL) {
                        Link(destination: url) {
                            Label("Abrir en GitHub (\(viewModel.repo.htmlURL))", systemImage: "safari.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo.opacity(0.15)))
                        }
                    }

                    Button(role: .destructive) {
                        onClose()
                    } label: {
                        Label("Cerrar Pantalla y Ejecutar `RepoDetailModule.teardown()`", systemImage: "trash.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.16)))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .navigationTitle(viewModel.repo.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { onClose() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 440)
    }

    private var scopeMemoryBanner: some View {
        HStack {
            Image(systemName: "memorychip.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scope Activo en RAM: `RepoDetailModule`")
                    .font(.caption.bold())
                Text("Instancia: `\(viewModel.instanceID)` · Objetos en scope: \(viewModel.activeObjectsInScope)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.12)))
    }
}
