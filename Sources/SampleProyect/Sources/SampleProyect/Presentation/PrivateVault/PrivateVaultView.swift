//
//  PrivateVaultView.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Scoped Feature View
//  Visualización protegida de la bóveda privada asegurada por Dagger DAG.
//

import SwiftUI

public struct PrivateVaultView: View {
    @StateObject private var viewModel: PrivateVaultViewModel
    public let onClose: () -> Void

    public init(session: ActiveVaultSession, onClose: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: PrivateVaultViewModel(session: session))
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lock.open.shield.fill")
                        .font(.title)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("Módulo Protegido Inicializado")
                            .font(.headline)
                        Text("Precondición `ValidatedSession` verificada para @\(viewModel.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                ForEach(viewModel.keys, id: \.self) { secret in
                    Text(secret)
                        .font(.caption.monospaced())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                }

                Spacer()

                Button {
                    onClose()
                } label: {
                    Label("Cerrar Scope y Destruir `PrivateVaultModule` en RAM", systemImage: "xmark.shield.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.2)))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .navigationTitle("PrivateVaultModule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { onClose() }
                }
            }
        }
        .frame(minWidth: 360, minHeight: 360)
    }
}
