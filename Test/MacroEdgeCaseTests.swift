//
//  MacroEdgeCaseTests.swift
//  Casos de borde de @Inject / @Module que antes fallaban (parser sin swift-syntax).
//

import Testing
import DaggerSwift

@Inject
final class EdgeDep: Sendable {}

/// `let a, b: Int`: ambos son Int (antes: no compilaba).
@Inject
struct EdgeTwoInts: Sendable {
    let a, b: Int
    let dep: EdgeDep
}

/// `let a: Int, b: String`: cada uno con su tipo.
@Inject
struct EdgeMixedList: Sendable {
    let count: Int, name: String
}

/// `init` con valor por defecto: el grafo NO lo resuelve, se usa el default (antes: pedía Int al grafo).
@Inject
final class EdgeWithDefaults: Sendable {
    let dep: EdgeDep
    let retries: Int

    init(dep: EdgeDep, retries: Int = 3) {
        self.dep = dep
        self.retries = retries
    }
}

/// La palabra "class" dentro del cuerpo de un struct no lo vuelve clase.
@Inject
struct EdgeClassWord: Sendable {
    let dep: EdgeDep
    var label: String { "subclass of nothing" }
}

final class EdgeBox<T>: @unchecked Sendable {
    let make: () -> T
    init(make: @escaping () -> T) { self.make = make }
}

@Module
enum EdgeModule {
    /// Closures dentro de genéricos en el tipo de retorno.
    @Singleton
    static func box() -> EdgeBox<(Int, String) -> Bool> { EdgeBox { { _, _ in true } } }

    /// Parámetro con default en una función del módulo: tampoco se pide al grafo.
    @Provider
    static func greeting(dep: EdgeDep, prefix: String = "hola") -> String { "\(prefix) \(dep)" }
}

@Suite("Macros: casos de borde del parser")
struct MacroEdgeCaseTests {

    @Test("let a, b: Int y let a: Int, b: String generan init con todos los nombres")
    func multipleBindings() throws {
        #expect(EdgeTwoInts(a: 1, b: 2, dep: EdgeDep()).b == 2)
        #expect(EdgeMixedList(count: 3, name: "x").name == "x")

        let root = ScopeContainer.root()
        root.bindInstance(7, as: Int.self)
        let resolved = try root.resolve(EdgeTwoInts.self)
        #expect(resolved.a == 7 && resolved.b == 7)
    }

    @Test("init con default: se resuelve sin pedir el parámetro al grafo")
    func initDefaults() throws {
        let value = try ScopeContainer.root().resolve(EdgeWithDefaults.self)
        #expect(value.retries == 3)
    }

    @Test("struct con la palabra class y closures en genéricos")
    func classWordAndGenericClosures() throws {
        _ = try ScopeContainer.root().resolve(EdgeClassWord.self)
        let root = ScopeContainer.root(modules: [EdgeModule.self])
        let box = try root.resolve(EdgeBox<(Int, String) -> Bool>.self)
        #expect(box.make()(1, "a"))
        #expect(try root.resolve(String.self).hasPrefix("hola"))
    }
}
