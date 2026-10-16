//
//  RepoBentoCardView.swift
//  Features
//
//  Capa Features · Tarjeta Social Bento (Inyectada cuando @BusinessRule devuelve .bento).
//

import SwiftUI
import AppFoundation

public struct RepoBentoCardView: View {
    public let repo: GitHubRepoItem
    public let onSelect: () -> Void

    public init(repo: GitHubRepoItem, onSelect: @escaping () -> Void) {
        self.repo = repo
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 10) {
                // Encabezado
                HStack(spacing: 8) {
                    Image(systemName: repo.isPrivateVault ? "lock.shield.fill" : "book.closed.fill")
                        .font(.subheadline)
                        .foregroundStyle(repo.isPrivateVault ? .orange : .blue)

                    Text(repo.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if repo.name.lowercased() == "dagger-swift" {
                        Text("DESTACADO")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.indigo.opacity(0.15)))
                            .foregroundStyle(.indigo)
                    } else if repo.isPrivateVault {
                        Text("@PRECONDITION")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.15)))
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }

                // Descripción
                Text(repo.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Footer con dot de lenguaje, estrellas, forks y licencia
                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(languageColor)
                            .frame(width: 9, height: 9)
                        Text(repo.language)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("\(repo.stars)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "tuningfork")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(repo.forks)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(repo.licenseName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.1)))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.showcaseCardBackground)
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var languageColor: Color {
        switch repo.language.lowercased() {
        case "swift": return Color(red: 0.94, green: 0.32, blue: 0.22)
        case "typescript": return Color(red: 0.19, green: 0.47, blue: 0.78)
        case "javascript": return Color(red: 0.97, green: 0.87, blue: 0.12)
        default: return Color.secondary
        }
    }
}
