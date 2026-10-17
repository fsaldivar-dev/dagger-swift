//
//  RepoDetailView.swift
//  Features
//
//  Capa Features · Vista Scoped de Detalle de Repositorio.
//  Al cerrarse, ejecuta `RepoDetailModule.teardown()` liberando sus objetos de RAM.
//

import SwiftUI
import AppFoundation

public struct RepoDetailView: View {
    public let session: ActiveRepoSession
    public let onClose: () -> Void

    private var repo: GitHubRepoItem { session.repo }

    public init(session: ActiveRepoSession, onClose: @escaping () -> Void) {
        self.session = session
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scopeMemoryBanner

                    Text(repo.fullName)
                        .font(.title2.bold())

                    Text(repo.description)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 14) {
                        Label("\(repo.stars)", systemImage: "star.fill")
                        Label("\(repo.forks)", systemImage: "tuningfork")
                        Label(repo.language, systemImage: "chevron.left.forwardslash.chevron.right")
                        Label(repo.licenseName, systemImage: "checkmark.seal")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)

                    if !repo.architectureNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notas de Arquitectura")
                                .font(.headline)
                            Text(repo.architectureNotes)
                                .font(.callout)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.showcaseCardBackground))
                    }

                    if !repo.sampleFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Archivos Clave")
                                .font(.headline)
                            ForEach(repo.sampleFiles, id: \.self) { file in
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundStyle(.indigo)
                                    Text(file)
                                        .font(.caption.monospaced())
                                    Spacer()
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.showcaseSubtleFill))
                            }
                        }
                    }

                    if let url = URL(string: repo.htmlURL) {
                        Link(destination: url) {
                            Label("Ver en GitHub", systemImage: "safari.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo.opacity(0.15)))
                        }
                    }

                    Button(role: .destructive) {
                        onClose()
                    } label: {
                        Label("Cerrar y Liberar Scope (`teardownScope()`)", systemImage: "trash.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.red.opacity(0.14)))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .navigationTitle(repo.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { onClose() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 420)
    }

    private var scopeMemoryBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "memorychip.fill")
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sub-Scope Activo: `RepoDetailModule`")
                    .font(.caption.bold())
                Text("ID: `\(session.inspector.instanceID)` · Sesión: @\(session.inspector.session.username)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.green.opacity(0.12)))
    }
}
