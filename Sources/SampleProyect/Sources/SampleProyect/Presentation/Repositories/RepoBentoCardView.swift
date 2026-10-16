//
//  RepoBentoCardView.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Reusable Component
//  Tarjeta interactiva estilo Bento Grid para la visualización rica de repositorios.
//

import SwiftUI

public struct RepoBentoCardView: View {
    public let repo: GitHubRepoItem
    public let onSelect: () -> Void

    public init(repo: GitHubRepoItem, onSelect: @escaping () -> Void) {
        self.repo = repo
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                // Cabecera: Nombre + Pill de Lenguaje
                HStack(alignment: .center) {
                    HStack(spacing: 8) {
                        Image(systemName: repo.isPrivateVault ? "lock.shield.fill" : "shippingbox.fill")
                            .font(.subheadline)
                            .foregroundStyle(repo.isPrivateVault ? .orange : .indigo)
                        Text(repo.name)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Indicador de Lenguaje con dot de color oficial
                    HStack(spacing: 5) {
                        Circle()
                            .fill(languageColor)
                            .frame(width: 8, height: 8)
                        Text(repo.language)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(languageColor.opacity(0.12)))
                }

                // Descripción
                Text(repo.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)

                // Nota de Arquitectura (Clean Architecture Callout)
                if !repo.architectureNotes.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "cpu")
                            .font(.caption.bold())
                            .foregroundStyle(.indigo)
                            .padding(.top, 1)

                        Text(repo.architectureNotes)
                            .font(.caption2)
                            .foregroundStyle(.primary.opacity(0.85))
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.indigo.opacity(0.06))
                    )
                }

                // Fila de Engagement Social (Stars, Forks, Licencia y Botón de Scope)
                HStack(spacing: 14) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text("\(repo.stars)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if repo.forks > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "tuningfork")
                                .foregroundStyle(.secondary)
                            Text("\(repo.forks)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.teal)
                        Text(repo.licenseName)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Inspeccionar")
                            .font(.caption.weight(.bold))
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(repo.isPrivateVault ? .orange : .indigo)
                }
                .font(.caption)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.showcaseCardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        repo.isPrivateVault ? Color.orange.opacity(0.4) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var languageColor: Color {
        switch repo.language.lowercased() {
        case "swift": return Color(red: 0.94, green: 0.32, blue: 0.22)
        case "typescript": return Color(red: 0.19, green: 0.47, blue: 0.78)
        case "javascript": return Color(red: 0.97, green: 0.87, blue: 0.12)
        case "python": return Color(red: 0.22, green: 0.46, blue: 0.67)
        default: return Color.secondary
        }
    }
}
