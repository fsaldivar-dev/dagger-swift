//
//  DeepLinksLabView.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Feature View
//  Laboratorio de pruebas para disparar Deep Links y observar la validación del DAG.
//

import SwiftUI

public struct DeepLinksLabView: View {
    @ObservedObject public var viewModel: DeepLinksViewModel
    @ObservedObject public var coordinator: ShowcaseCoordinator

    public init(viewModel: DeepLinksViewModel, coordinator: ShowcaseCoordinator) {
        self.viewModel = viewModel
        self.coordinator = coordinator
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Estado de Precondición
                preconditionStatusCard

                Text("Simulador de Deep Links (`daggerswift://`)")
                    .font(.headline)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260, maximum: 500), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(viewModel.presets) { link in
                        Button {
                            coordinator.handleDeepLink(link)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(link.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text(link.urlString)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.indigo)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.secondary.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.indigo.opacity(0.25), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                Text("Bitácora en Vivo: Grafo vs. Coordinador")
                    .font(.headline)

                ForEach(coordinator.eventLogs.prefix(8)) { log in
                    eventLogRow(log)
                }
            }
            .padding(16)
        }
    }

    private var preconditionStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: viewModel.isAuthenticated ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.isAuthenticated ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Precondición del Grafo: `ValidatedSession`")
                        .font(.headline)
                    Text(
                        viewModel.isAuthenticated
                        ? "Estado: ACTIVA (@\(viewModel.currentUsername ?? "fsaldivar-dev")). Los Deep Links protegidos se resolverán inmediatamente."
                        : "Estado: NO AUTENTICADO. Si disparas un Deep Link protegido, el Grafo lanzará `GraphError.unmetPrecondition` antes de reservar memoria y el Coordinador abrirá el Login Gate."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.login(coordinator: coordinator)
                } label: {
                    Label("Autenticar como @fsaldivar-dev", systemImage: "person.badge.key.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.2)))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isAuthenticated)

                Button {
                    viewModel.logout(coordinator: coordinator)
                } label: {
                    Label("Cerrar Sesión (Invalidar Nodo)", systemImage: "lock.rotation")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.15)))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isAuthenticated)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func eventLogRow(_ log: ScopeEventLog) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(log.category)
                .font(.caption2.bold().monospaced())
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(log.isError ? Color.red.opacity(0.18) : Color.indigo.opacity(0.15))
                )
                .foregroundStyle(log.isError ? .red : .indigo)

            Text(log.message)
                .font(.caption)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondary.opacity(0.05))
        )
    }
}
