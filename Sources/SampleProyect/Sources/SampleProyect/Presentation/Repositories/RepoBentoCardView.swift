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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: repo.isPrivateVault ? "lock.shield.fill" : "shippingbox.fill")
                        .foregroundStyle(repo.isPrivateVault ? .orange : .indigo)
                    Text(repo.name)
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(repo.language)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.indigo.opacity(0.15)))
                        .foregroundStyle(.indigo)
                }

                Text(repo.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if !repo.architectureNotes.isEmpty {
                    Text(repo.architectureNotes)
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.8))
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.08))
                        )
                }

                HStack(spacing: 12) {
                    Label("\(repo.stars)", systemImage: "star.fill")
                        .foregroundStyle(.yellow)
                    Label("\(repo.forks)", systemImage: "tuningfork")
                        .foregroundStyle(.secondary)
                    Label(repo.licenseName, systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.teal)
                    Spacer()
                    Text(repo.isPrivateVault ? "Exige ValidatedSession →" : "Crear Scope Hijo →")
                        .font(.caption2.bold())
                        .foregroundStyle(repo.isPrivateVault ? .orange : .indigo)
                }
                .font(.caption2)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondary.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                repo.isPrivateVault ? Color.orange.opacity(0.45) : Color.indigo.opacity(0.22),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
