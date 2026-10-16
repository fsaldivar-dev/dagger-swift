//
//  GetManifestoChaptersUseCase.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Use Case
//  Obtiene los capítulos del Manifiesto y memoria técnica de DaggerSwift.
//

import Foundation

public struct GetManifestoChaptersUseCase: Sendable {
    private let manifestoRepository: any ManifestoRepositoryProtocol

    public init(manifestoRepository: any ManifestoRepositoryProtocol) {
        self.manifestoRepository = manifestoRepository
    }

    public func execute() -> [ManifestoChapter] {
        manifestoRepository.getChapters()
    }
}
