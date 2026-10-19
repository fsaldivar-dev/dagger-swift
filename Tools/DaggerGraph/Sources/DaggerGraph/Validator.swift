//
//  Validator.swift
//  dagger-graph
//
//  Validaciones sobre la unión de hechos de todos los archivos:
//  1. Bindings faltantes (ningún @Module lo provee y no es un tipo @Inject).
//  2. Ciclos (Tarjan SCC, reporta el ciclo completo).
//  3. Violación de scope: un @Singleton (contenedor raíz) que depende — directo o vía nodos
//     transient — de algo que solo vive en un scope hijo.
//

import Foundation

struct Diagnostic: Codable, Sendable, Hashable, Comparable {
    enum Severity: String, Codable, Sendable { case error, warning, note }
    var file: String
    var loc: Loc
    var severity: Severity
    var message: String

    var rendered: String { "\(file):\(loc.line):\(loc.col): \(severity.rawValue): \(message)" }

    static func < (a: Diagnostic, b: Diagnostic) -> Bool {
        (a.file, a.loc.line, a.loc.col, a.message) < (b.file, b.loc.line, b.loc.col, b.message)
    }
}

struct Validator {
    struct Node {
        let file: String
        let binding: Binding
    }

    /// Tipos que el runtime siempre sabe resolver.
    static let builtins: Set<String> = ["ScopeContainer", "DaggerSwift.ScopeContainer"]

    let nodes: [Node]
    let dynamic: [(file: String, reg: DynamicRegistration)]
    let roots: [(file: String, root: RootFact, parent: Int?)]
    /// Módulos extra a importar en el código generado (`generate --import M`).
    var extraImports: Set<String> = []
    let modules: [String: (file: String, fact: ModuleFact)]
    private var providers: [String: [Int]] = [:]
    private var providersByLastComponent: [String: [Int]] = [:]
    private let dynamicTypes: [String: (String, Loc)]

    init(facts: [(file: String, facts: FileFacts)]) {
        var nodes: [Node] = []
        var dynamic: [(String, DynamicRegistration)] = []
        var roots: [(String, RootFact, Int?)] = []
        var modules: [String: (String, ModuleFact)] = [:]
        for (file, f) in facts {
            nodes += f.bindings.map { Node(file: file, binding: $0) }
            dynamic += f.dynamic.map { (file, $0) }
            let offset = roots.count
            roots += f.roots.map { (file, $0, $0.parent.map { $0 + offset }) }
            for m in f.modules where modules[m.name] == nil { modules[m.name] = (file, m) }
        }
        self.nodes = nodes
        self.dynamic = dynamic
        self.roots = roots
        self.modules = modules
        var dyn: [String: (String, Loc)] = [:]
        for (file, reg) in dynamic { if let t = reg.type, dyn[t] == nil { dyn[t] = (file, reg.loc) } }
        self.dynamicTypes = dyn
        for (i, n) in nodes.enumerated() {
            providers[n.binding.provides, default: []].append(i)
            if let last = n.binding.provides.split(separator: ".").last.map(String.init), last != n.binding.provides {
                providersByLastComponent[last, default: []].append(i)
            }
        }
    }

    func providerIndices(for type: String) -> [Int]? {
        if let p = providers[type] { return p }
        if let p = providersByLastComponent[type] { return p }
        // `Foo.Bar` escrito calificado pero declarado vía extensión con otro prefijo.
        if let last = type.split(separator: ".").last.map(String.init), last != type { return providers[last] }
        return nil
    }

    func run() -> [Diagnostic] {
        // Cada grupo = un diagnóstico principal + sus notas (se mantienen juntas al ordenar).
        var groups = Set(missingBindings().map { [$0] })
        groups.formUnion(cycles())
        groups.formUnion(scopeViolations().map { [$0] })
        groups.formUnion(rootDiagnostics())
        return groups.sorted { $0[0] < $1[0] }.flatMap { $0 }
    }

    // MARK: 1. Bindings faltantes

    private func missingBindings() -> [Diagnostic] {
        var out: [Diagnostic] = []
        for n in nodes {
            for d in n.binding.deps where !Self.builtins.contains(d.type) && providerIndices(for: d.type) == nil {
                if let (dFile, dLoc) = dynamicTypes[d.type] {
                    out.append(Diagnostic(
                        file: n.file, loc: d.loc, severity: .warning,
                        message: "'\(d.type)' (requerido por \(n.binding.origin)) solo se registra dinámicamente en runtime (\(dFile):\(dLoc.line)); no verificable en compile-time"
                    ))
                } else {
                    out.append(Diagnostic(
                        file: n.file, loc: d.loc, severity: .error,
                        message: "binding faltante: '\(d.type)' requerido por \(n.binding.origin); ningún @Module lo provee y no es un tipo @Inject"
                    ))
                }
            }
        }
        return out
    }

    // MARK: 2. Ciclos (Tarjan)

    private func edges() -> [String: [(to: String, via: Int, dep: Dependency)]] {
        var g: [String: [(String, Int, Dependency)]] = [:]
        for (i, n) in nodes.enumerated() {
            g[n.binding.provides, default: []] += []
            for d in n.binding.deps {
                guard let targets = providerIndices(for: d.type) else { continue }
                for t in Set(targets.map { nodes[$0].binding.provides }) {
                    g[n.binding.provides, default: []].append((t, i, d))
                }
            }
        }
        return g
    }

    private func cycles() -> [[Diagnostic]] {
        let g = edges()
        var index = 0
        var indices: [String: Int] = [:]
        var lowlink: [String: Int] = [:]
        var onStack = Set<String>()
        var stack: [String] = []
        var sccs: [[String]] = []

        func strongConnect(_ v: String) {
            indices[v] = index; lowlink[v] = index; index += 1
            stack.append(v); onStack.insert(v)
            for e in g[v] ?? [] {
                if indices[e.to] == nil {
                    strongConnect(e.to)
                    lowlink[v] = min(lowlink[v]!, lowlink[e.to]!)
                } else if onStack.contains(e.to) {
                    lowlink[v] = min(lowlink[v]!, indices[e.to]!)
                }
            }
            if lowlink[v] == indices[v] {
                var scc: [String] = []
                while true {
                    let w = stack.removeLast(); onStack.remove(w); scc.append(w)
                    if w == v { break }
                }
                sccs.append(scc)
            }
        }
        for v in g.keys.sorted() where indices[v] == nil { strongConnect(v) }

        var out: [[Diagnostic]] = []
        for scc in sccs {
            let members = Set(scc)
            let selfLoop = scc.count == 1 && (g[scc[0]] ?? []).contains { $0.to == scc[0] }
            guard scc.count > 1 || selfLoop else { continue }
            // Reconstruye un ciclo concreto dentro del SCC (DFS desde el menor nombre).
            let start = scc.min()!
            var path: [(String, Int, Dependency)] = []
            var visited = Set<String>()
            func dfs(_ v: String) -> Bool {
                visited.insert(v)
                for e in (g[v] ?? []) where members.contains(e.to) {
                    path.append((v, e.via, e.dep))
                    if e.to == start { return true }
                    if !visited.contains(e.to), dfs(e.to) { return true }
                    path.removeLast()
                }
                return false
            }
            guard dfs(start), let first = path.first else { continue }
            let chain = (path.map { $0.0 } + [start]).joined(separator: " -> ")
            var group = [Diagnostic(
                file: nodes[first.1].file, loc: first.2.loc, severity: .error,
                message: "ciclo de dependencias: \(chain)"
            )]
            for step in path.dropFirst() {
                group.append(Diagnostic(
                    file: nodes[step.1].file, loc: step.2.loc, severity: .note,
                    message: "parte del ciclo: \(nodes[step.1].binding.origin) depende de '\(step.2.type)'"
                ))
            }
            out.append(group)
        }
        return out
    }

    // MARK: 3. Scope

    private func scopeViolations() -> [Diagnostic] {
        var out: [Diagnostic] = []
        for n in nodes where n.binding.lifetime == .root {
            var visited = Set<String>()
            func walk(_ deps: [Dependency], root: Dependency?) {
                for d in deps {
                    guard let idx = providerIndices(for: d.type), !visited.contains(d.type) else { continue }
                    visited.insert(d.type)
                    let provs = idx.map { nodes[$0].binding }
                    let scopes = provs.compactMap { b -> String? in if case .scope(let s) = b.lifetime { return s } else { return nil } }
                    // Solo se reporta si TODOS los proveedores viven en un scope hijo (sin ambigüedad).
                    if scopes.count == provs.count, let s = scopes.first {
                        let at = root ?? d
                        out.append(Diagnostic(
                            file: n.file, loc: at.loc, severity: .error,
                            message: "violación de scope: \(n.binding.origin) es @Singleton (contenedor raíz) pero depende de '\(d.type)', que solo vive en scope \(s)"
                        ))
                    } else {
                        for b in provs where b.lifetime == .transient { walk(b.deps, root: root ?? d) }
                    }
                }
            }
            walk(n.binding.deps, root: nil)
        }
        return out
    }
}

// MARK: - 4. Validación por raíz de composición

extension Validator {
    /// Módulos efectivos de una raíz (incluye los del padre y `includes` transitivos), en orden de registro.
    func registrationOrder(of index: Int, visitedRoots: Set<Int> = []) -> (modules: [String], unknown: [String], literal: Bool) {
        let entry = roots[index]
        var order: [String] = []
        var unknown: [String] = []
        var literal = true
        if let p = entry.parent, !visitedRoots.contains(p) {
            let parent = registrationOrder(of: p, visitedRoots: visitedRoots.union([index]))
            order = parent.modules
            unknown = parent.unknown
            literal = parent.literal
        }
        guard let listed = entry.root.modules else { return (order, unknown, false) }
        var seen = Set(order)
        func visit(_ name: String) {
            guard let module = modules[name]?.fact else {
                // `makeChildScope(for: S.self)` con S que no es @Module es legítimo (scope o precondición).
                if entry.root.kind != .childScope || name != listed.first { unknown.append(name) }
                return
            }
            for inc in module.includes { visit(inc) }
            if seen.insert(name).inserted { order.append(name) }
        }
        listed.forEach(visit)
        return (order, unknown, literal)
    }

    /// Scopes que un módulo deja abiertos al registrarse en una caja: su `scope:` y sus `includes`
    /// (cada include agrega su propio scope compatible), como hace `register(in:)` de la macro.
    func compatibleScopes(of module: String, visited: Set<String> = []) -> Set<String> {
        guard let fact = modules[module]?.fact, !visited.contains(module) else { return [] }
        var out = Set<String>()
        if let s = fact.scope { out.insert(s) }
        for inc in fact.includes {
            out.insert(inc)
            out.formUnion(compatibleScopes(of: inc, visited: visited.union([module])))
        }
        return out
    }

    /// Scopes abiertos en la caja desde la que resuelve la raíz (además de Global).
    func openScopes(of index: Int, visited: Set<Int> = []) -> Set<String> {
        let entry = roots[index]
        let listed = entry.root.modules ?? []
        switch entry.root.kind {
        case .root, .buildGraph:
            // ScopeContainer.root: la caja Global ignora addCompatibleScope.
            return []
        case .expectGraph, .expectWhenCondition, .whenResolved:
            // DaggerSwiftTesting abre un hijo por cada módulo listado.
            return listed.reduce(into: Set<String>()) { $0.insert($1); $0.formUnion(compatibleScopes(of: $1)) }
        case .moduleResolve:
            // Modulo.resolve: hijo del runtime con el scope del módulo + extras registrados en él.
            guard let first = listed.first else { return [] }
            var out: Set<String> = [first]
            for m in listed { out.formUnion(compatibleScopes(of: m)) }
            return out
        case .childScope:
            var out = Set<String>()
            if let p = entry.parent, !visited.contains(p) { out = openScopes(of: p, visited: visited.union([index])) }
            if let scope = listed.first { out.insert(scope) }
            for m in listed { out.formUnion(compatibleScopes(of: m)) }
            return out
        }
    }

    func rootDiagnostics() -> [[Diagnostic]] {
        var out: [[Diagnostic]] = []
        for (i, entry) in roots.enumerated() {
            let root = entry.root
            if let receiver = root.receiverModule, modules[receiver] == nil {
                continue // `X.resolve(...)` / `X.buildGraph()` sobre algo que no es @Module: no es una raíz.
            }
            let (order, unknown, literal) = registrationOrder(of: i)
            guard literal else {
                out.append([Diagnostic(
                    file: entry.file, loc: root.loc, severity: .warning,
                    message: "raíz '\(root.text)': la lista de módulos no es literal; no se pudo validar estáticamente"
                )])
                continue
            }
            // Un hijo sin padre conocido puede recibir bindings del padre: solo se valida si el padre es conocido.
            if root.kind == .childScope && entry.parent == nil { continue }

            for name in unknown {
                out.append([Diagnostic(
                    file: entry.file, loc: root.loc, severity: .warning,
                    message: "raíz '\(root.text)': el módulo '\(name)' no está en el código analizado (¿otro paquete? usa --manifest)"
                )])
            }

            // Proveedor efectivo por tipo: el último registrado gana (como en runtime).
            var effective: [String: Int] = [:]
            for module in order {
                for (idx, node) in nodes.enumerated() where node.binding.module == module {
                    effective[node.binding.provides] = idx
                }
            }
            let provided = Set(root.provided)
            func provider(_ type: String) -> Int? {
                if let i = effective[type] { return i }
                if let last = type.split(separator: ".").last.map(String.init), let i = effective[last] { return i }
                // @Inject: se registra Just-In-Time en cualquier grafo.
                return providerIndices(for: type)?.first { nodes[$0].binding.kind == .inject }
            }

            let expectsFailure = !root.expectedMissing.isEmpty
            let severity: Diagnostic.Severity = expectsFailure ? .note : .error
            var reported = Set<String>()
            var visited = Set<String>()

            func check(_ type: String, requiredBy: String, at depFile: String, _ depLoc: Loc) {
                if Self.builtins.contains(type) || provided.contains(type) { return }
                guard let idx = provider(type) else {
                    guard reported.insert(type).inserted else { return }
                    let suffix = expectsFailure ? " (el test lo espera: unresolvedFailure)" : ""
                    let mods = order.isEmpty ? "ninguno" : order.joined(separator: ", ")
                    out.append([
                        Diagnostic(
                            file: entry.file, loc: root.loc, severity: severity,
                            message: "raíz '\(root.text)': '\(type)' requerido por \(requiredBy) no lo provee ningún módulo de esta raíz [\(mods)]\(suffix)"
                        ),
                        Diagnostic(file: depFile, loc: depLoc, severity: .note, message: "'\(type)' se pide aquí"),
                    ])
                    return
                }
                guard visited.insert(type).inserted else { return }
                let node = nodes[idx]
                for d in node.binding.deps {
                    check(d.type, requiredBy: node.binding.origin, at: node.file, d.loc)
                }
            }

            // Bindings efectivos de los módulos de la raíz + tipos pedidos por el test.
            for idx in Set(effective.values).sorted() {
                let node = nodes[idx]
                visited.insert(node.binding.provides)
                for d in node.binding.deps {
                    check(d.type, requiredBy: node.binding.origin, at: node.file, d.loc)
                }
            }
            // Tipos pedidos explícitamente: existencia + scope abierto.
            let open = openScopes(of: i)
            for req in root.requested {
                let reqSeverity: Diagnostic.Severity = (req.expectsFailure || expectsFailure) ? .note : .error
                let suffix = req.expectsFailure ? " (el test lo espera: #expect(throws:))" : ""
                if !req.expectsFailure {
                    check(req.type, requiredBy: "el test", at: entry.file, req.loc)
                } else if provider(req.type) == nil, !provided.contains(req.type) {
                    out.append([Diagnostic(
                        file: entry.file, loc: req.loc, severity: .note,
                        message: "raíz '\(root.text)': '\(req.type)' no está registrado\(suffix)"
                    )])
                    continue
                }
                // scopeNotActive estático: algún @Scoped(X) del subgrafo vive en un scope que esta raíz nunca abre.
                var seen = Set<String>()
                var stack = [req.type]
                while let type = stack.popLast() {
                    guard seen.insert(type).inserted, !provided.contains(type), let idx = provider(type) else { continue }
                    let b = nodes[idx].binding
                    if case .scope(let x) = b.lifetime, !open.contains(x) {
                        let opened = open.isEmpty ? "solo Global" : open.sorted().joined(separator: ", ")
                        out.append([
                            Diagnostic(
                                file: entry.file, loc: req.loc, severity: reqSeverity,
                                message: "raíz '\(root.text)': pedir '\(req.type)' necesita el scope '\(x)' (por \(b.origin)), que esta raíz nunca abre [abiertos: \(opened)] — scopeNotActive en runtime; usa makeChildScope(for: \(x).self)\(suffix)"
                            ),
                            Diagnostic(file: nodes[idx].file, loc: b.loc, severity: .note, message: "'\(b.provides)' vive en el scope '\(x)'"),
                        ])
                        break
                    }
                    stack.append(contentsOf: b.deps.map(\.type))
                }
            }
        }
        return out
    }
}
