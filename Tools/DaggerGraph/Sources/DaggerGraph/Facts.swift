//
//  Facts.swift
//  dagger-graph
//
//  Hechos extraídos por archivo (serializables al caché JSON).
//

import Foundation

struct Loc: Codable, Sendable, Hashable {
    var line: Int
    var col: Int
}

struct Dependency: Codable, Sendable, Hashable {
    /// Tipo normalizado (sin `any`, sin paréntesis, sin espacios).
    var type: String
    var loc: Loc
}

enum BindingKind: String, Codable, Sendable {
    case inject, singleton, scoped, provider, businessRule, precondition
}

/// Dónde vive la instancia en runtime.
/// - `root`: `@Singleton` (se construye desde el contenedor raíz).
/// - `scope(X)`: `@Scoped` / `@Inject(scope:)` (caja dueña del scope X).
/// - `transient`: `@Provider`, `@BusinessRule`, `@Precondition`, `@Inject` sin scope.
enum Lifetime: Codable, Sendable, Hashable {
    case root
    case scope(String)
    case transient

    var label: String {
        switch self {
        case .root: return "@Singleton"
        case .scope(let s): return "scope \(s)"
        case .transient: return "transient"
        }
    }
}

struct Binding: Codable, Sendable {
    var provides: String
    var kind: BindingKind
    var lifetime: Lifetime
    /// `Module.función` o el nombre del tipo `@Inject`.
    var origin: String
    var loc: Loc
    var deps: [Dependency]
}

struct ModuleFact: Codable, Sendable {
    var name: String
    var scope: String?
    var includes: [String]
    var loc: Loc
}

/// Registro imperativo (`bindInstance`, `provideScoped(...)`, etc.): solo existe en runtime,
/// en un contenedor concreto. Se usa para degradar "binding faltante" a advertencia.
struct DynamicRegistration: Codable, Sendable {
    var call: String
    var type: String?
    var loc: Loc
}

struct FileFacts: Codable, Sendable {
    var bindings: [Binding] = []
    var modules: [ModuleFact] = []
    var dynamic: [DynamicRegistration] = []
}

enum TypeName {
    /// `(any Foo)` → `Foo`, `any  Foo.Bar` → `Foo.Bar`, `DaggerSwift.ScopeContainer` → igual.
    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("@escaping ") { s = String(s.dropFirst("@escaping ".count)) }
        while s.hasPrefix("("), s.hasSuffix(")"), balancedOuterParens(s) {
            s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        }
        for prefix in ["any ", "some "] where s.hasPrefix(prefix) {
            s = String(s.dropFirst(prefix.count))
        }
        return s.filter { !$0.isWhitespace }
    }

    static func stripSelf(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasSuffix(".self") { s = String(s.dropLast(5)) }
        return normalize(s)
    }

    private static func balancedOuterParens(_ s: String) -> Bool {
        var depth = 0
        for (i, ch) in s.enumerated() {
            if ch == "(" { depth += 1 }
            if ch == ")" { depth -= 1 }
            if depth == 0 && i < s.count - 1 { return false }
        }
        return true
    }
}
