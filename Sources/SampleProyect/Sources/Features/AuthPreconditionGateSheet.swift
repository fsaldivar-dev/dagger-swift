//
//  AuthPreconditionGateSheet.swift
//  Features
//
//  Capa Features · Modal de Precondición (@Precondition ValidatedSession).
//  Se presenta cuando el grafo aborta una resolución por falta de sesión activa.
//

import SwiftUI
import AppFoundation

public struct AuthPreconditionGateSheet: View {
    public let reason: String
    public let onAuthenticate: () -> Void
    public let onCancel: () -> Void

    public init(
        reason: String,
        onAuthenticate: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.reason = reason
        self.onAuthenticate = onAuthenticate
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.orange)
                }

                Text("Precondición Requerida")
                    .font(.title3.bold())

                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 10) {
                    Button(action: onAuthenticate) {
                        Label("Iniciar Sesión (@fsaldivar-dev) y Continuar", systemImage: "key.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.green))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button("Cancelar", role: .cancel, action: onCancel)
                        .font(.subheadline)
                        .padding(6)
                }
            }
            .padding(24)
            .navigationTitle("@Precondition Guard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.medium])
    }
}
