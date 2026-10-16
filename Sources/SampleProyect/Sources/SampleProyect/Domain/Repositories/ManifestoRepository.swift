//
//  ManifestoRepository.swift
//  SampleProyect
//
//  Clean Architecture · Domain Layer · Repository Protocol
//  Define el contrato para leer capítulos del Manifiesto y memoria de arquitectura.
//

import Foundation

public protocol ManifestoRepositoryProtocol: Sendable {
    func getChapters() -> [ManifestoChapter]
}
