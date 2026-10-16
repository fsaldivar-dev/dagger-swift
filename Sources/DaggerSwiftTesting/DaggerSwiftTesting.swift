//
//  DaggerSwiftTesting.swift
//  DaggerSwiftTesting
//
//  Utilidades simples para probar y visualizar el grafo en Swift Testing (`import Testing`).
//

import Foundation
import Testing
import DaggerSwift

// MARK: - 1. Tags para filtrar tests en Xcode

public extension Tag {
    @Tag static var graph: Self
    @Tag static var precondition: Self
    @Tag static var businessRule: Self
}

// MARK: - 2. JSON Legible del Grafo ("Quién necesita a quién")

public struct ReadableGraphJSON: Codable, Sendable {
    public let scope: String
    public let objetosVivosEnRAM: Int
    public let dependencias: [String]
    public let subScopes: [ReadableGraphJSON]

    public init(from snapshot: GraphScopeSnapshot) {
        self.scope = Self.clean(snapshot.scope)
        self.objetosVivosEnRAM = snapshot.activeInstanceCount
        self.dependencias = snapshot.nodes.map { node in
            let typeName = Self.clean(node.type)
            let deps = node.dependencies.map(Self.clean)
            if deps.isEmpty {
                return "\(typeName) (\(node.kind))"
            } else {
                return "\(typeName) (\(node.kind)) -> necesita: [\(deps.joined(separator: ", "))]"
            }
        }
        self.subScopes = snapshot.children.map { ReadableGraphJSON(from: $0) }
    }

    fileprivate static func clean(_ raw: String) -> String {
        raw.replacingOccurrences(of: "any ", with: "")
            .split(separator: ".")
            .last
            .map(String.init) ?? raw
    }
}

// MARK: - 3. JSON Legible cuando algo falla en el Grafo

public struct ReadableGraphErrorJSON: Codable, Sendable {
    public let intentoResolver: String
    public let resultado: String
    public let caminoRecorrido: String
    public let motivoDelError: String
    public let objetosCreadosEnRAM: Int
}

// MARK: - 4. Helpers simples en ScopeContainer

public extension ScopeContainer {

    /// Adjunta al test en Xcode un archivo JSON fácil de leer con todas las conexiones del grafo.
    @discardableResult
    func attachGraphJSON(named fileName: String = "grafo.json") -> ReadableGraphJSON {
        let readable = ReadableGraphJSON(from: self.snapshot())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(readable),
           let json = String(data: data, encoding: .utf8) {
            Attachment.record(json, named: fileName)
        }
        return readable
    }

    /// Adjunta al test en Xcode un archivo JSON explicando en qué paso falló la resolución del grafo.
    @discardableResult
    func attachErrorJSON<T>(
        for targetType: T.Type,
        error: any Error,
        named fileName: String = "error-grafo.json"
    ) -> ReadableGraphErrorJSON {
        let trace = self.lastFailureTrace.map(ReadableGraphJSON.clean)
        let pathString: String
        if trace.isEmpty {
            pathString = "❌ \(ReadableGraphJSON.clean(String(reflecting: T.self)))"
        } else {
            let allButLast = trace.dropLast()
            let last = trace.last!
            pathString = (allButLast + ["❌ \(last)"]).joined(separator: " -> ")
        }

        let report = ReadableGraphErrorJSON(
            intentoResolver: ReadableGraphJSON.clean(String(reflecting: T.self)),
            resultado: "BLOQUEADO / ERROR",
            caminoRecorrido: pathString,
            motivoDelError: String(describing: error),
            objetosCreadosEnRAM: self.activeInstanceCount
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(report),
           let json = String(data: data, encoding: .utf8) {
            Attachment.record(json, named: fileName)
        }
        return report
    }
}
