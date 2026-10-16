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
                Image(systemName: repo.isPrivateVault ? "lock.fill" : "folder.fill")
                    .foregroundStyle(repo.isPrivateVault ? .orange : .blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.fullName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(repo.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(repo.language)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.07))
            )
        }
        .buttonStyle(.plain)
    }
}
