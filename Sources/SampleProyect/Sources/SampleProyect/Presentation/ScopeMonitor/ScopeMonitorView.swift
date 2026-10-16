//
//  ScopeMonitorView.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Feature View
//  Monitor en vivo del motor DAG de DaggerSwift v2 y auditoría ARC de fugas en RAM.
//

import SwiftUI

public struct ScopeMonitorView: View {
    @ObservedObject public var viewModel: ScopeMonitorViewModel
    @ObservedObject public var coordinator: ShowcaseCoordinator

    public init(viewModel: ScopeMonitorViewModel, coordinator: ShowcaseCoordinator) {
        self.viewModel = viewModel
        self.coordinator = coordinator
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Tarjetas de Métricas de Memoria
                metricsGrid

                // Sección del Stress Test
                stressTestSection

                Text("Historial Completo de Eventos del Grafo")
                    .font(.headline)

                ForEach(coordinator.eventLogs) { log in
                    eventLogRow(log)
                }
            }
            .padding(16)
        }
    }

    private var metricsGrid: some View {
        HStack(spacing: 12) {
            metricCard(
                title: "Scopes Creados",
                value: "\(coordinator.totalScopesCreated)",
                subtitle: "Global + Módulos Hijos",
                tint: .indigo
            )
            metricCard(
                title: "Scopes Liberados",
                value: "\(coordinator.totalScopesTornDown)",
                subtitle: "teardown() ejecutados",
                tint: .teal
            )
            metricCard(
                title: "Fugas en RAM",
                value: "\(coordinator.lastLeakAuditCount)",
                subtitle: "Auditoría WeakObjectBox",
                tint: .green
            )
        }
    }

    private var stressTestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prueba de Estrés de Memoria (Creación y Destrucción de Sub-Scopes)")
                .font(.headline)
            Text("Instancia 25 sub-scopes hijos (`RepoDetailModule`) con sus respectivos `RepoDetailInspector`, ejecuta `teardown()` y verifica mediante `WeakObjectBox` que ARC libere el 100% de las referencias.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                viewModel.runStressTest(coordinator: coordinator)
            } label: {
                Label("Ejecutar Stress Test (25 Scopes en Ráfaga)", systemImage: "bolt.shield.fill")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.07)))
    }

    private func metricCard(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(tint)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tint.opacity(0.1))
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
