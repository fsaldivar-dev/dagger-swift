//
//  ManifestoViewModel.swift
//  SampleProyect
//
//  Clean Architecture · Presentation Layer · MVVM ViewModel
//  Gobierna la lectura interactiva del Manifiesto Open Source.
//

import Foundation
import SwiftUI
import DaggerSwift

@MainActor
@Inject
public final class ManifestoViewModel: ObservableObject {
    private let getChaptersUseCase: GetManifestoChaptersUseCase

    @Published public var chapters: [ManifestoChapter] = []
    @Published public var selectedChapterID: String = "gigantes"

    public init(getChaptersUseCase: GetManifestoChaptersUseCase) {
        self.getChaptersUseCase = getChaptersUseCase
        self.chapters = getChaptersUseCase.execute()
    }

    public var activeChapter: ManifestoChapter? {
        chapters.first(where: { $0.id == selectedChapterID }) ?? chapters.first
    }

    public func selectChapter(_ id: String) {
        self.selectedChapterID = id
    }
}
