//
//  Generator.swift
//  dagger-graph
//
//  `dagger-graph generate`: por cada raíz literal emite factories tipadas DIRECTAS
//  (sin `container.resolve`, sin diccionarios, sin `Any`), con la misma semántica del runtime:
//  - `@Singleton`: una instancia por grafo (almacenada en la clase raíz).
//  - `@Scoped` / `@Inject(scope:)`: una instancia por scope (clase del scope, un archivo por scope).
//  - `@Provider`, `@BusinessRule`, `@Inject`: llamada directa en cada acceso.
//  - `@Precondition`: `guard let` + `throw GraphError.unmetPrecondition`.
//  Es opt-in y reversible: si no se usa el código generado, el runtime sigue igual.
//  Thread-safety: si algún tipo es `@MainActor`, la clase entera se marca `@MainActor`; si no, un
//  `NSRecursiveLock` por grafo (compartido con sus scopes) garantiza construcción única.
//

import Foundation

struct GeneratedFile {
    let name: String
    let content: String
}

extension Validator {
    private enum Home: Hashable {
        case root
        case scope(String)
    }

    func generate(rootsIn filter: String?, targetModule: String?) -> (files: [GeneratedFile], skipped: [String], smoke: [String], imports: Set<String>) {
        var files: [GeneratedFile] = []
        var skipped: [String] = []
        var smoke: [String] = []
        var imports = Set<String>()
        var seenGraphs = Set<String>()

        for (i, entry) in roots.enumerated() {
            let root = entry.root
            if let filter, !entry.file.hasPrefix(filter) { continue }
            // Los hijos se modelan como clases de scope dentro del grafo de su raíz.
            if root.kind == .childScope { continue }
            if let receiver = root.receiverModule, modules[receiver] == nil { continue }
            let (order, unknown, literal) = registrationOrder(of: i)
            guard literal, !order.isEmpty, unknown.isEmpty else { continue }
            let graphName = "DaggerGraph_" + order.filter { name in
                // Nombre estable: solo los módulos listados (los includes ya van implícitos).
                (root.modules ?? []).contains(name)
            }.joined(separator: "_")
            guard seenGraphs.insert(graphName).inserted else { continue }

            let result = emitGraph(named: graphName, order: order, listed: root.modules ?? [], targetModule: targetModule)
            files += result.files
            skipped += result.skipped.map { "\(graphName): \($0)" }
            smoke.append(result.smoke)
            imports.formUnion(result.imports)
        }
        return (files, skipped, smoke, imports)
    }

    /// Archivo de tests de humo: cada raíz se arma con el RUNTIME y se resuelve cada binding desde la
    /// caja donde vive. Falla solo con errores de programación; los de estado (precondición) son válidos.
    static func smokeTestFile(_ functions: [String], imports: Set<String>) -> String {
        var out = header
        out += (imports.union(["Testing"])).sorted().map { "import \($0)" }.joined(separator: "\n") + "\n\n"
        out += """
        /// Resuelve `type` y registra un Issue solo si es un error de programación (debió detectarse al compilar).
        private func smokeResolve<T>(_ container: ScopeContainer, _ type: T.Type, sourceLocation: SourceLocation = #_sourceLocation) {
            do {
                _ = try container.resolve(type)
            } catch let error as GraphError where !error.isProgrammerError {
                // Estado (p. ej. @Precondition sin sesión): válido en un test de humo.
            } catch {
                Issue.record("\\(String(reflecting: type)): \\(error)", sourceLocation: sourceLocation)
            }
        }

        @Suite("Humo: cada raíz resuelve con el runtime (generado por dagger-graph)")
        struct DaggerGraphSmokeTests {

        """
        out += functions.joined(separator: "\n")
        out += "}\n"
        return out
    }

    // MARK: - Un grafo

    private func emitGraph(named graphName: String, order: [String], listed: [String], targetModule: String?) -> (files: [GeneratedFile], skipped: [String], smoke: String, imports: Set<String>) {
        // Proveedor efectivo por tipo (el último registrado gana) + tipos @Inject (Just-In-Time).
        // Un tipo/módulo declarado en varios targets (p. ej. el mismo Fake en dos targets de test):
        // se prefiere la declaración del target de salida; si no, la primera.
        func preferred(_ candidates: [Int]) -> Int? {
            candidates.first { Self.moduleName(forFile: nodes[$0].file) == targetModule } ?? candidates.first
        }
        var effective: [String: Int] = [:]
        for module in order {
            let decls = nodes.indices.filter { nodes[$0].binding.module == module }
            let files = Set(decls.map { nodes[$0].file })
            let chosenFile = files.first { Self.moduleName(forFile: $0) == targetModule } ?? modules[module]?.file
            for idx in decls where nodes[idx].file == chosenFile {
                effective[nodes[idx].binding.provides] = idx
            }
        }
        func provider(_ type: String) -> Int? {
            if let i = effective[type] { return i }
            if let last = type.split(separator: ".").last.map(String.init), let i = effective[last] { return i }
            return preferred(providerIndices(for: type)?.filter { nodes[$0].binding.kind == .inject } ?? [])
        }

        // Jerarquía de scopes inferida de las dependencias: si algo @Scoped(X) depende de algo que vive
        // en el scope Y, Y es ancestro de X (Global → Sesión → Feature).
        var parentOf: [String: String] = [:]
        func isAncestor(_ a: String, of b: String) -> Bool {
            var current = parentOf[b]
            var hops = 0
            while let c = current, hops < 64 {
                if c == a { return true }
                current = parentOf[c]
                hops += 1
            }
            return false
        }
        func depth(_ h: Home) -> Int {
            guard case .scope(var s) = h else { return 0 }
            var d = 1
            while let p = parentOf[s], d < 64 { s = p; d += 1 }
            return d
        }

        // Dónde vive cada nodo: raíz, o el scope más profundo de la cadena de la que depende. nil = no generable.
        var homes: [Int: Home?] = [:]
        var reasons: [Int: String] = [:]
        func home(_ idx: Int, stack: Set<Int> = []) -> Home? {
            if let cached = homes[idx] { return cached }
            if stack.contains(idx) {
                reasons[idx] = "ciclo"
                return nil
            }
            let b = nodes[idx].binding
            var scopes = Set<String>()
            for d in b.deps {
                if Self.builtins.contains(d.type) {
                    reasons[idx] = "depende de ScopeContainer"
                    homes[idx] = .some(nil)
                    return nil
                }
                guard let p = provider(d.type) else {
                    reasons[idx] = "falta '\(d.type)' en este grafo"
                    homes[idx] = .some(nil)
                    return nil
                }
                guard let h = home(p, stack: stack.union([idx])) else {
                    reasons[idx] = "depende de '\(d.type)', que no es generable"
                    homes[idx] = .some(nil)
                    return nil
                }
                if case .scope(let s) = h { scopes.insert(s) }
            }
            let result: Home?
            switch b.lifetime {
            case .root:
                result = scopes.isEmpty ? .root : nil
                if result == nil { reasons[idx] = "@Singleton que depende de un scope" }
            case .scope(let s):
                var ok = true
                for y in scopes where y != s {
                    if parentOf[s] == nil && !isAncestor(s, of: y) {
                        parentOf[s] = y // primera evidencia: Y contiene a X
                    }
                    if !isAncestor(y, of: s) { ok = false }
                }
                result = ok ? .scope(s) : nil
                if result == nil { reasons[idx] = "depende de scopes que no son ancestros de '\(s)'" }
            case .transient:
                // Vive en el scope más profundo, si todos los demás son sus ancestros.
                let deepest = scopes.first { d in scopes.allSatisfy { $0 == d || isAncestor($0, of: d) } }
                if scopes.isEmpty {
                    result = .root
                } else if let deepest {
                    result = .scope(deepest)
                } else {
                    result = nil
                    reasons[idx] = "depende de scopes hermanos"
                }
            }
            homes[idx] = .some(result)
            return result
        }

        // Candidatos: bindings efectivos de los módulos + todos los @Inject.
        var candidates = Set(effective.values)
        for (idx, node) in nodes.enumerated() where node.binding.kind == .inject {
            // Si un @Inject y un módulo proveen el mismo tipo, gana el módulo (como en runtime).
            if effective[node.binding.provides] == nil { candidates.insert(idx) }
        }
        // Un tipo @Inject declarado en varios archivos (p. ej. dos targets de test) se genera una vez.
        var byType: [String: Int] = [:]
        for idx in candidates.sorted() {
            let type = nodes[idx].binding.provides
            if let current = byType[type], preferred([current, idx]) == current { continue }
            byType[type] = idx
        }

        // Primera pasada: los @Scoped fijan la jerarquía; segunda: hogares definitivos con ella.
        for idx in byType.values.sorted() where nodes[idx].binding.lifetime != .transient { _ = home(idx) }
        homes.removeAll()
        reasons.removeAll()

        var rootNodes: [Int] = []
        var scopeNodes: [String: [Int]] = [:]
        var skipped: [String] = []
        for (type, idx) in byType.sorted(by: { $0.key < $1.key }) {
            switch home(idx) {
            case .root: rootNodes.append(idx)
            case .scope(let s): scopeNodes[s, default: []].append(idx)
            case nil:
                // Los @Inject que no pertenecen a este grafo se omiten en silencio; solo se reportan
                // los bindings de los módulos de la raíz que no se pudieron generar.
                if nodes[idx].binding.kind != .inject {
                    skipped.append("\(type) (\(reasons[idx] ?? "no generable"))")
                }
            }
        }
        let usedNodes = rootNodes + scopeNodes.values.flatMap { $0 }
        let mainActor = usedNodes.contains { nodes[$0].binding.isMainActor }
        let isolation = mainActor ? "@MainActor\n" : ""
        // Thread-safety: @MainActor si algún tipo lo es; si no, un lock recursivo por grafo (compartido con
        // sus scopes) protege cada @Singleton/@Scoped: se construyen una sola vez aunque haya concurrencia.
        let lockLine = mainActor ? "" : "        lock.lock(); defer { lock.unlock() }\n"
        let sendable = mainActor ? "" : ": @unchecked Sendable"

        func accessor(_ idx: Int) -> String { Self.accessorName(nodes[idx].binding.provides) }
        /// Expresión que construye el nodo y, si tiene `@Precondition` directas, un preludio que
        /// las evalúa PRIMERO (mismo orden que el runtime: 0 allocations si una falla).
        func call(_ idx: Int, from home: Home) -> (prelude: [String], expr: String) {
            let b = nodes[idx].binding
            func target(_ d: Dependency) -> String {
                let p = provider(d.type)!
                // Subir tantos `parent.` como niveles separen al nodo de su dependencia.
                let hops = max(0, depth(home) - depth(self.homeOf(p, homes) ?? .root))
                return String(repeating: "parent.", count: hops) + "\(accessor(p))()"
            }
            let isPrecondition = b.deps.map { nodes[provider($0.type)!].binding.kind == .precondition }
            let hoist = isPrecondition.contains(true) && isPrecondition.first == false
            var prelude: [String] = []
            var argValues = b.deps.map(target).map { "try " + $0 }
            if hoist {
                let order = b.deps.indices.sorted { (isPrecondition[$0] ? 0 : 1, $0) < (isPrecondition[$1] ? 0 : 1, $1) }
                for i in order {
                    prelude.append("let arg\(i) = \(argValues[i])")
                    argValues[i] = "arg\(i)"
                }
            }
            let args = zip(b.deps, argValues).map { d, v in
                let value = hoist ? v : String(v.dropFirst(4))
                return d.label == "_" ? value : "\(d.label): \(value)"
            }.joined(separator: ", ")
            let needsTry = b.isThrowing || (!b.deps.isEmpty && !hoist)
            let prefix = needsTry ? "try " : ""
            switch b.kind {
            case .inject:
                return (prelude, "\(prefix)\(b.provides)(\(args))")
            default:
                return (prelude, "\(prefix)\(b.module!).\(b.function!)(\(args))")
            }
        }

        func body(_ idx: Int, home: Home) -> String {
            let b = nodes[idx].binding
            let name = accessor(idx)
            let type = Self.returnType(b)
            let (prelude, expr) = call(idx, from: home)
            let pre = prelude.map { "        \($0)\n" }.joined()
            switch b.kind {
            case .singleton, .scoped:
                return """
                    private var _\(name): \(Self.optionalStorage(type))
                    func \(name)() throws -> \(type) {
                \(lockLine)        if let cached = _\(name) { return cached }
                \(pre)        let value = \(expr)
                        _\(name) = value
                        return value
                    }
                """
            case .inject where b.lifetime != .transient:
                return """
                    private var _\(name): \(type)?
                    func \(name)() throws -> \(type) {
                \(lockLine)        if let cached = _\(name) { return cached }
                \(pre)        let value = \(expr)
                        _\(name) = value
                        return value
                    }
                """
            case .precondition:
                let reason = b.reason ?? "Precondición requerida (\(type)) no satisfecha"
                return """
                    func \(name)() throws -> \(type) {
                \(pre)        guard let value = \(expr) else {
                            throw GraphError.unmetPrecondition(type: String(reflecting: \(Self.metatype(type))), reason: \(Self.literal(reason)))
                        }
                        return value
                    }
                """
            default:
                return """
                    func \(name)() throws -> \(type) {
                \(pre)        \(prelude.isEmpty ? "" : "return ")\(expr)
                    }
                """
            }
        }

        let imports = importsHeader(for: usedNodes, targetModule: targetModule, foundation: !mainActor)
        let importSet = Set(imports.split(separator: "\n").map { $0.replacingOccurrences(of: "import ", with: "") })

        // Test de humo con el runtime para esta raíz.
        var smoke = "    @Test(\"Humo · [\(listed.joined(separator: ", "))]\")\n"
        smoke += mainActor ? "    @MainActor\n" : ""
        smoke += "    func smoke_\(graphName)() {\n"
        smoke += "        let root = ScopeContainer.root(modules: [\(listed.map { "\($0).self" }.joined(separator: ", "))])\n"
        let scopeNames = Self.scopesTopologically(Set(scopeNodes.keys).union(parentOf.values.filter { _ in true }), parentOf: parentOf)
        for scope in scopeNames {
            let parentBox = parentOf[scope].map { "\(Self.accessorName($0))Box" } ?? "root"
            smoke += "        let \(Self.accessorName(scope))Box = \(parentBox).makeChildScope(for: \(scope).self)\n"
        }
        for idx in rootNodes {
            smoke += "        smokeResolve(root, \(Self.metatype(Self.returnType(nodes[idx].binding))))\n"
        }
        for scope in scopeNames {
            for idx in scopeNodes[scope] ?? [] {
                smoke += "        smokeResolve(\(Self.accessorName(scope))Box, \(Self.metatype(Self.returnType(nodes[idx].binding))))\n"
            }
        }
        smoke += "    }\n"
        var files: [GeneratedFile] = []

        var rootFile = Self.header + imports
        rootFile += "\n/// Grafo generado para la raíz [\(order.joined(separator: ", "))]: factories directas, sin `resolve`.\n"
        rootFile += "\(isolation)final class \(graphName)\(sendable) {\n"
        rootFile += mainActor ? "    init() {}\n" : "    let lock = NSRecursiveLock()\n    init() {}\n"
        for scope in scopeNames where parentOf[scope] == nil {
            rootFile += "\n    /// Abre el scope `\(scope)` (sus `@Scoped` viven mientras viva el objeto devuelto).\n"
            rootFile += "    func make\(Self.typeIdentifier(scope))() -> \(Self.scopeClass(scope)) { \(Self.scopeClass(scope))(parent: self) }\n"
        }
        for idx in rootNodes {
            rootFile += "\n" + body(idx, home: .root) + "\n"
        }
        rootFile += "}\n"
        files.append(GeneratedFile(name: "\(graphName).swift", content: rootFile))

        for scope in scopeNames {
            var f = Self.header + imports
            f += "\nextension \(graphName) {\n"
            f += "    /// Scope `\(scope)` del grafo [\(order.joined(separator: ", "))].\n"
            f += "    \(isolation.isEmpty ? "" : "@MainActor\n    ")final class \(Self.scopeClass(scope))\(sendable) {\n"
            let parentClass = parentOf[scope].map(Self.scopeClass) ?? graphName
            f += "        let parent: \(parentClass)\n        init(parent: \(parentClass)) { self.parent = parent }\n"
            if !mainActor { f += "        var lock: NSRecursiveLock { parent.lock }\n" }
            for child in scopeNames where parentOf[child] == scope {
                f += "\n        /// Abre el scope hijo `\(child)`.\n"
                f += "        func make\(Self.typeIdentifier(child))() -> \(Self.scopeClass(child)) { \(Self.scopeClass(child))(parent: self) }\n"
            }
            for idx in scopeNodes[scope] ?? [] {
                f += "\n" + body(idx, home: .scope(scope)).split(separator: "\n", omittingEmptySubsequences: false)
                    .map { $0.isEmpty ? "" : "    " + $0 }.joined(separator: "\n") + "\n"
            }
            f += "    }\n}\n"
            files.append(GeneratedFile(name: "\(graphName)+\(Self.typeIdentifier(scope)).swift", content: f))
        }
        return (files, skipped, smoke, importSet)
    }

    /// Scopes ordenados de padres a hijos (para abrir las cajas en el orden correcto).
    static func scopesTopologically(_ scopes: Set<String>, parentOf: [String: String]) -> [String] {
        func depth(_ s: String) -> Int {
            var d = 0, cur = s
            while let p = parentOf[cur], d < 64 { cur = p; d += 1 }
            return d
        }
        return scopes.sorted { (depth($0), $0) < (depth($1), $1) }
    }

    private func homeOf(_ idx: Int, _ homes: [Int: Home?]) -> Home? {
        homes[idx] ?? nil
    }

    // MARK: - Utilidades de emisión

    static let header = "// Generado por `dagger-graph generate`. No editar: se reescribe solo si cambia.\n// swiftlint:disable all\n\n"

    /// `import` de DaggerSwift + los módulos de los archivos que declaran los nodos usados
    /// (+ `--import M` para tipos declarados en módulos sin bindings, p. ej. protocolos en `Core`).
    private func importsHeader(for used: [Int], targetModule: String?, foundation: Bool) -> String {
        var mods = Set(["DaggerSwift"]).union(extraImports)
        if foundation { mods.insert("Foundation") }
        for idx in used {
            if let m = Self.moduleName(forFile: nodes[idx].file), m != targetModule { mods.insert(m) }
        }
        return mods.sorted().map { "import \($0)" }.joined(separator: "\n") + "\n"
    }

    /// Heurística SwiftPM: el directorio inmediatamente bajo el último `Sources/` o `Tests/`.
    static func moduleName(forFile path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard let i = parts.lastIndex(where: { $0 == "Sources" || $0 == "Tests" }), i + 1 < parts.count - 1 else { return nil }
        return parts[i + 1]
    }

    static func accessorName(_ type: String) -> String {
        let id = typeIdentifier(type)
        return id.prefix(1).lowercased() + id.dropFirst()
    }

    static func typeIdentifier(_ type: String) -> String {
        type.split(separator: ".").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }

    static func scopeClass(_ scope: String) -> String { typeIdentifier(scope) + "Graph" }

    static func returnType(_ b: Binding) -> String {
        var t = b.spelledType.isEmpty ? b.provides : b.spelledType
        if b.kind == .precondition, t.hasSuffix("?") { t.removeLast() }
        return t.trimmingCharacters(in: .whitespaces)
    }

    static func optionalStorage(_ type: String) -> String {
        type.contains(" ") ? "(\(type))?" : "\(type)?"
    }

    static func metatype(_ type: String) -> String {
        type.contains(" ") ? "(\(type)).self" : "\(type).self"
    }

    static func literal(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
