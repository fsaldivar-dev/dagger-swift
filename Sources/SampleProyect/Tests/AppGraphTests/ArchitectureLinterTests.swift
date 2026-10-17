//
//  ArchitectureLinterTests.swift
//  SampleProyect · Architecture, SOLID, Clean & Simplicity Linter
//
//  Audita automáticamente todo el código fuente de `Sources/SampleProyect/Sources`
//  para garantizar lo que revisará el Tech Lead:
//  - [RULE-01] División estricta por capas (Domain, Data, Presentation) y cero `*Composer.swift` manuales
//  - [RULE-02] Pureza de Domain (Cero `import SwiftUI`, cero referencias a `*Impl`, `*Actor` o `Live*`)
//  - [RULE-03] UseCases con `@Inject`, `func execute` y Ley de Demeter (repositorios encapsulados, no `public let`)
//  - [RULE-04] UnCoupling en Presentation (ViewModels con `@Inject`, cero instanciación de tipos de `Data`)
//  - [RULE-05] Plug & UnPlug modular con `@Module` y `teardownScope()`
//  - [RULE-06] Cero `try!`, `try?`, `ScopeContainer`, `NSLock`, `@unchecked Sendable`
//  - [RULE-07] Simplicidad de lectura (máximo 180 líneas por archivo en los ejemplos)
//

import Foundation
import Testing

@Suite("0. Linter de Arquitectura: Capas, SOLID, Clean, UnCoupling y Simplicidad")
struct ArchitectureLinterTests {

    struct SourceFile {
        let relativePath: String
        let url: URL
        let content: String
        let lines: [String]
        let codeLinesWithoutComments: [String]
    }

    private func loadAllSampleSources() throws -> [SourceFile] {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let packageRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourcesRoot = packageRoot.appendingPathComponent("Sources")

        let fm = FileManager.default
        let enumerator = fm.enumerator(at: sourcesRoot, includingPropertiesForKeys: nil)!
        var result: [SourceFile] = []

        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let relPath = fileURL.path.replacingOccurrences(of: sourcesRoot.path + "/", with: "")
            let allLines = content.components(separatedBy: .newlines)
            let codeLines = allLines.map { line -> String in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                    return ""
                }
                if let commentRange = line.range(of: "//") {
                    if !line[..<commentRange.lowerBound].hasSuffix(":") {
                        return String(line[..<commentRange.lowerBound])
                    }
                }
                return line
            }
            result.append(
                SourceFile(
                    relativePath: relPath,
                    url: fileURL,
                    content: content,
                    lines: allLines,
                    codeLinesWithoutComments: codeLines
                )
            )
        }
        return result.sorted { $0.relativePath < $1.relativePath }
    }

    @Test("Auditoría completa del Linter sobre Sources/SampleProyect/Sources")
    func runArchitectureAndSolidLinter() throws {
        let files = try loadAllSampleSources()
        var violations: [String] = []
        let allPaths = Set(files.map(\.relativePath))

        // =========================================================================
        // [RULE-01] División por Capas (Domain / Data / Presentation)
        // =========================================================================
        for feature in ["MultiCountryNewsDemo", "FintechMockupDemo"] {
            let requiredLayers = [
                "\(feature)/Domain/Entities/",
                "\(feature)/Domain/Repositories/",
                "\(feature)/Domain/UseCases/",
                "\(feature)/Data/Repositories/",
                "\(feature)/Data/DI/",
                "\(feature)/Presentation/View/",
                "\(feature)/Presentation/ViewModel/"
            ]
            for layerPrefix in requiredLayers {
                if !allPaths.contains(where: { $0.hasPrefix(layerPrefix) }) {
                    violations.append("[RULE-01 · División por Capas] Falta la capa obligatoria `\(layerPrefix)`.")
                }
            }
        }

        for file in files {
            let path = file.relativePath
            let code = file.codeLinesWithoutComments.joined(separator: "\n")

            if path.contains("Composer") {
                violations.append("[RULE-01 · No Manual Composers] \(path): Elimina los Composers manuales; usa Plug & UnPlug directo con `@Module` y `@Inject`.")
            }

            // =========================================================================
            // [RULE-02] Pureza de la capa Domain (Domain/ y Core/)
            // =========================================================================
            let isDomainFile = path.contains("/Domain/") || path.hasPrefix("Core/")
            if isDomainFile {
                if code.contains("import SwiftUI") {
                    violations.append("[RULE-02 · Pureza Domain] \(path): La capa Domain no puede hacer `import SwiftUI`.")
                }
                let forbiddenInDomain = ["Impl", "Actor", "LiveGitHub"]
                for token in forbiddenInDomain where code.contains(token) {
                    violations.append("[RULE-02 · Pureza Domain] \(path): La capa Domain referencia un detalle de implementación (`\(token)`).")
                }
            }

            // =========================================================================
            // [RULE-03] Encapsulamiento y SRP en UseCases (Ley de Demeter)
            // =========================================================================
            if path.contains("UseCase") {
                if !code.contains("@Inject") {
                    violations.append("[RULE-03 · SOLID UseCase] \(path): Todo UseCase debe usar `@Inject`.")
                }
                if !code.contains("func execute") {
                    violations.append("[RULE-03 · SOLID UseCase] \(path): Todo UseCase debe exponer su acción mediante `func execute(...)`.")
                }
                if code.contains("public let gitHubRepository") ||
                   code.contains("public let coreBanking") ||
                   code.contains("public let cardEngine") ||
                   code.contains("public let newsRepository") ||
                   code.contains("public let localeProvider") {
                    violations.append("[RULE-03 · Ley de Demeter] \(path): Los repositorios dentro de un UseCase no deben ser `public let`.")
                }
            }

            // =========================================================================
            // [RULE-04] UnCoupling en Presentation (ViewModel y View)
            // =========================================================================
            let isPresentationFile = path.contains("/Presentation/") || path.hasPrefix("Features/")
            if isPresentationFile {
                let forbiddenConcreteInPresentation = [
                    "Impl(",
                    "LocaleProvider(",
                    "NewsRepository(",
                    "CardEngineV",
                    "LiveGitHubRepository(",
                    "AuthSessionRepository(",
                    "Actor("
                ]
                for token in forbiddenConcreteInPresentation where code.contains(token) {
                    violations.append("[RULE-04 · UnCoupling Presentation] \(path): Presentation instancia un tipo concreto de Data (`\(token)`).")
                }

                let demeterViolations = [
                    ".coreBanking.",
                    ".gitHubRepository.",
                    ".newsRepository.",
                    ".localeProvider."
                ]
                for token in demeterViolations where code.contains(token) {
                    violations.append("[RULE-04 · Ley de Demeter] \(path): Presentation atraviesa un UseCase para llamar a `\(token)` directamente.")
                }
            }

            // =========================================================================
            // [RULE-05] MVVM + Plug & UnPlug en ViewModels y Módulos DI
            // =========================================================================
            if path.contains("ViewModel") {
                if !code.contains("@Inject") {
                    violations.append("[RULE-04 · MVVM + DI] \(path): Todo ViewModel debe usar `@Inject`.")
                }
                if !code.contains("@MainActor") {
                    violations.append("[RULE-04 · Concurrencia UI] \(path): Todo ViewModel debe estar aislado con `@MainActor`.")
                }
                if !code.contains("teardownScope()") {
                    violations.append("[RULE-05 · Plug & UnPlug] \(path): Todo ViewModel debe liberar su scope al desconectar un módulo (`teardownScope()`).")
                }
            }

            if path.contains("/DI/") || path.hasPrefix("Services/ServiceModules") {
                if !code.contains("@Module") {
                    violations.append("[RULE-05 · Plug & UnPlug] \(path): Los archivos de DI deben declarar `@Module`.")
                }
            }

            // =========================================================================
            // [RULE-06] Cero `try!`, `try?`, `ScopeContainer`, `NSLock`, `@unchecked Sendable`
            // =========================================================================
            for (idx, rawLine) in file.codeLinesWithoutComments.enumerated() {
                let lineNum = idx + 1
                if rawLine.range(of: #"\btry!"#, options: .regularExpression) != nil {
                    violations.append("[RULE-06 · Safety] \(path):\(lineNum) Uso prohibido de `try!`.")
                }
                if rawLine.range(of: #"\btry\?"#, options: .regularExpression) != nil {
                    violations.append("[RULE-06 · Safety] \(path):\(lineNum) Uso prohibido de `try?`.")
                }
                if rawLine.contains("ScopeContainer") && !rawLine.contains("\"Sources/DaggerSwift/ScopeContainer.swift\"") {
                    violations.append("[RULE-06 · Abstracción DI] \(path):\(lineNum) Uso prohibido de `ScopeContainer` en la app.")
                }
                if rawLine.contains("NSLock") || rawLine.contains("NSRecursiveLock") {
                    violations.append("[RULE-06 · Concurrencia Swift 6] \(path):\(lineNum) Uso prohibido de `NSLock` (usa `actor` o `@MainActor`).")
                }
                if rawLine.contains("@unchecked Sendable") {
                    violations.append("[RULE-06 · Concurrencia Swift 6] \(path):\(lineNum) Uso prohibido de `@unchecked Sendable`.")
                }
            }

            // =========================================================================
            // [RULE-07] Simplicidad de Lectura (Máximo 180 líneas por archivo)
            // =========================================================================
            let maxLines = 180
            if file.lines.count > maxLines {
                violations.append("[RULE-07 · Simplicidad] \(path) tiene \(file.lines.count) líneas (máximo permitido: \(maxLines) líneas para mantener ejemplos ultra simples).")
            }
        }

        if !violations.isEmpty {
            let report = (["❌ Se encontraron \(violations.count) violaciones del Linter de Arquitectura y SOLID:"] + violations.map { "  • \($0)" })
                .joined(separator: "\n")
            Issue.record(Comment(rawValue: report))
        }
    }
}
