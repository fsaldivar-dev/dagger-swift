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
    /// Etiqueta externa con la que se pasa al `init`/función (`_` si no lleva). La usa `generate`.
    var label: String = "_"
    /// Tipo tal como está escrito en el código (para el código generado).
    var spelled: String = ""
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
    /// Módulo dueño (`nil` para tipos `@Inject`).
    var module: String? = nil
    /// Nombre de la función del `@Module` (para el código generado).
    var function: String? = nil
    var isThrowing: Bool = false
    /// Tipo provisto tal como está escrito (`any Foo`, `Foo?` en precondiciones).
    var spelledType: String = ""
    /// Tipo `@Inject` aislado a `@MainActor` (el código generado debe correr en el MainActor).
    var isMainActor: Bool = false
    /// Mensaje de `@Precondition("...")`, si lo tiene.
    var reason: String? = nil
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

/// Una raíz de composición escrita en el código: qué módulos arman un grafo concreto.
struct RootFact: Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case expectGraph, expectWhenCondition, root, buildGraph, childScope, moduleResolve, whenResolved
    }
    struct Requested: Codable, Sendable {
        var type: String
        var loc: Loc
        /// Dentro de `#expect(throws:)` / `#require(throws:)`: el test espera que falle.
        var expectsFailure: Bool = false
    }
    var kind: Kind
    /// Módulos en orden de registro; `nil` si la lista no es literal (no validable estáticamente).
    var modules: [String]?
    /// Para `buildGraph`/`resolve`/`whenResolved`: el tipo receptor (se valida que sea un @Module).
    var receiverModule: String?
    /// Raíz padre (índice en el mismo archivo) para `makeChildScope` sobre una raíz conocida.
    var parent: Int?
    /// Tipos que la cadena del test pide resolver (`.dependency(T.self)`, `.resolved(T.self)`).
    var requested: [Requested] = []
    /// Tipos que el test espera que NO resuelvan (`.dependency(T.self).unresolvedFailure()`).
    var expectedMissing: [String] = []
    /// Tipos inyectados por el test (`.whenResolved(T.self).returns(...)`).
    var provided: [String] = []
    var loc: Loc
    var text: String
}

/// Uso de un service locator (`X.register(service:)` / `X.shared.resolve()`), típico de apps que migran
/// a DaggerSwift (p. ej. Firefox con Dip). Permite auditar en compilación qué se pide sin registrarse.
struct LocatorUse: Codable, Sendable {
    /// Tipo registrado o pedido; `nil` si no se puede deducir del código (registro sin `as T`).
    var type: String?
    var loc: Loc
    var text: String
}

struct FileFacts: Codable, Sendable {
    var bindings: [Binding] = []
    var modules: [ModuleFact] = []
    var dynamic: [DynamicRegistration] = []
    var roots: [RootFact] = []
    var locatorRegistrations: [LocatorUse] = []
    var locatorRequests: [LocatorUse] = []
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

/// Manifiesto de grafo de un paquete/módulo (prototipo multi-paquete).
/// Cada paquete publica qué provee, qué requiere y qué scopes usa; la raíz los une con `--manifest`.
struct GraphManifest: Codable, Sendable {
    static let schema = 1
    var schema = GraphManifest.schema
    var name: String
    /// Tipos que este paquete sabe construir (@Module + @Inject).
    var provides: [String]
    /// Dependencias que este paquete NO resuelve por sí mismo (las debe proveer otro paquete o la raíz).
    var requires: [String]
    /// Scopes de los que dependen sus bindings.
    var scopes: [String]
    /// `@Module` declarados (con includes) para validar raíces que los usan.
    var modules: [String]
    /// Hechos completos por archivo (rutas relativas al paquete) para validar/generar sin re-parsear.
    var files: [String: FileFacts]
}
