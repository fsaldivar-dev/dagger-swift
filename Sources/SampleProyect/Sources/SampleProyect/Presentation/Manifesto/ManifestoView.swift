//
//  ManifestoView.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · Feature View
//  Lector inmersivo del Manifiesto Open Source de @fsaldivar-dev y memoria técnica DaggerSwift.
//

import SwiftUI

public struct ManifestoView: View {
    @ObservedObject public var viewModel: ManifestoViewModel

    public init(viewModel: ManifestoViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Selector de Capítulos
                chapterSelector

                if let activeChapter = viewModel.activeChapter {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(activeChapter.badge)
                            .font(.caption2.bold())
                            .foregroundStyle(.indigo)

                        Text(activeChapter.title)
                            .font(.title2.bold())

                        Text(activeChapter.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(activeChapter.quote)
                            .font(.callout.italic().weight(.medium))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.indigo.opacity(0.09))
                            )

                        ForEach(activeChapter.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.secondary.opacity(0.06))
                    )
                }
            }
            .padding(16)
        }
    }

    private var chapterSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.chapters) { chapter in
                    let isSelected = viewModel.selectedChapterID == chapter.id
                    Button {
                        viewModel.selectChapter(chapter.id)
                    } label: {
                        Text(chapter.title)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? Color.indigo : Color.secondary.opacity(0.12))
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
