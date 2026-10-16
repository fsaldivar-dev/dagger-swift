//
//  AuthPreconditionGateSheet.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Precondition Gate
//  Modal interactivo presentado cuando el Grafo DAG aborta la resolución
//  debido a una precondición `ValidatedSession` no cumplida.
//

import SwiftUI

public struct AuthPreconditionGateSheet: View {
    public let reason: String
    public let pendingDeepLink: ShowcaseDeepLink?
    public let onAuthenticate: () -> Void
    public let onCancel: () -> Void

    public init(
        reason: String,
        pendingDeepLink: ShowcaseDeepLink?,
        onAuthenticate: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.reason = reason
        self.pendingDeepLink = pendingDeepLink
        self.onAuthenticate = onAuthenticate
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "hand.raised.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Precondición del Grafo No Cumplida")
                .font(.title3.bold())

            Text(reason)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let pending = pendingDeepLink {
                VStack(spacing: 4) {
                    Text("Deep Link en espera de autenticación:")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                    Text(pending.urlString)
                        .font(.caption.monospaced())
                        .foregroundStyle(.indigo)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo.opacity(0.1)))
            }

            HStack(spacing: 12) {
                Button("Cancelar") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button {
                    onAuthenticate()
                } label: {
                    Label("Autenticar como @fsaldivar-dev y Continuar", systemImage: "key.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 320)
    }
}
