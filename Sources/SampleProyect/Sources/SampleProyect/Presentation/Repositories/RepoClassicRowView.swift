//
//  RepoClassicRowView.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Reusable Component
//  Fila de lista clásica tradicional (Sistema A).
//

import SwiftUI

public struct RepoClassicRowView: View {
    public let repo: GitHubRepoItem
    public let onSelect: () -> Void

    public init(repo: GitHubRepoItem, onSelect: @escaping () -> Void) {
        self.repo = repo
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icono
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(repo.fullName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(repo.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Lenguaje + Stars
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text("\(repo.stars)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.showcaseCardBackground)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
