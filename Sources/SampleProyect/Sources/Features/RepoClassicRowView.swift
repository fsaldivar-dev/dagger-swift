//
//  RepoClassicRowView.swift
//  Features
//
//  Capa Features · Fila Compacta (Inyectada cuando @BusinessRule devuelve .classic).
//

import SwiftUI
import AppFoundation

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
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill((repo.isPrivateVault ? Color.orange : Color.blue).opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: repo.isPrivateVault ? "lock.shield.fill" : "folder.fill")
                        .foregroundStyle(repo.isPrivateVault ? .orange : .blue)
                        .font(.subheadline)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(repo.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(repo.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text("\(repo.stars)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.showcaseCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
