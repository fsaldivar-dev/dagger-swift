//
//  DaggerSwiftMacrosPlugin.swift
//  DaggerSwiftMacros
//
//  Compiler Plugin nativo para DaggerSwift v2 (Protocolo JSON HostToPluginMessage de Swift 6).
//  Cero dependencias externas: compila en <0.3s y soporta:
//  - @Module (genera GraphScope, GraphModule, Modulable, register(in:) y buildGraph())
//  - @Inject / @Inject(scope:) (genera init limpio para Unit Tests + register(in:) y resolve(in:))
//  - @Singleton, @Provider (modo dual: Accessor para Dagger 1 + Peer Marker para Dagger 2)
//  - @Scoped, @BusinessRule, @Precondition
//

import Foundation

@main
struct DaggerSwiftMacrosPlugin {
    static func main() {
        while let messageData = readMessage() {
            guard
                let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any]
            else {
                continue
            }

            if json["getCapability"] != nil {
                let response: [String: Any] = [
                    "getCapabilityResult": [
                        "capability": [
                            "protocolVersion": 1,
                            "features": [] as [String]
                        ]
                    ]
                ]
                sendMessage(response)
            } else if let expand = json["expandAttachedMacro"] as? [String: Any] {
                let response = handleExpandAttachedMacro(expand)
                sendMessage(response)
            } else if json["expandFreestandingMacro"] != nil {
                let response: [String: Any] = [
                    "expandMacroResult": [
                        "expandedSource": "",
                        "diagnostics": [] as [Any]
                    ]
                ]
                sendMessage(response)
            }
        }
    }

    // MARK: - Wire Protocol (stdin / stdout length-prefixed JSON)

    private static func readExactBytes(count: Int) -> Data? {
        var buffer = Data()
        buffer.reserveCapacity(count)
        while buffer.count < count {
            let chunk = FileHandle.standardInput.readData(ofLength: count - buffer.count)
            if chunk.isEmpty {
                return nil
            }
            buffer.append(chunk)
        }
        return buffer
    }

    private static func readMessage() -> Data? {
        guard let header = readExactBytes(count: 8) else { return nil }
        let length = header.withUnsafeBytes { Int(UInt64(littleEndian: $0.load(as: UInt64.self))) }
        guard length > 0 else { return Data() }
        return readExactBytes(count: length)
    }

    private static func sendMessage(_ object: [String: Any]) {
        guard let payload = try? JSONSerialization.data(withJSONObject: object) else { return }
        var length = UInt64(payload.count).littleEndian
        let header = withUnsafeBytes(of: &length) { Data($0) }
        FileHandle.standardOutput.write(header)
        FileHandle.standardOutput.write(payload)
    }

    // MARK: - Dispatcher de Macros

    // MARK: - Diagnósticos (campo `diagnostics` del protocolo del plugin)

    /// Diagnósticos de la expansión en curso (un mensaje a la vez: el plugin es secuencial).
    nonisolated(unsafe) private static var pendingDiagnostics: [[String: Any]] = []
    nonisolated(unsafe) private static var currentDecl: (source: String, fileName: String, offset: Int)?

    /// Emite un error del compilador apuntando a `needle` dentro de la declaración (o a su inicio).
    static func diagnose(_ message: String, at needle: String?) {
        guard let decl = currentDecl else { return }
        var offset = decl.offset
        if let needle, let range = decl.source.range(of: needle) {
            offset += decl.source.utf8.distance(from: decl.source.startIndex, to: range.lowerBound)
        }
        pendingDiagnostics.append([
            "message": message,
            "severity": "error",
            "position": ["fileName": decl.fileName, "offset": offset],
            "highlights": [] as [Any],
            "notes": [] as [Any],
            "fixIts": [] as [Any],
        ])
    }

    /// El estado de diagnósticos es por expansión: se serializan (el compilador ya manda un mensaje a la
    /// vez; el lock protege usos concurrentes, p. ej. tests en paralelo).
    private static let expansionLock = NSLock()

    static func handleExpandAttachedMacro(_ payload: [String: Any]) -> [String: Any] {
        expansionLock.lock()
        defer { expansionLock.unlock() }
        return expandAttachedMacroLocked(payload)
    }

    private static func expandAttachedMacroLocked(_ payload: [String: Any]) -> [String: Any] {
        let macroInfo = payload["macro"] as? [String: Any]
        let typeName = (macroInfo?["typeName"] as? String) ?? ""
        let macroRole = (payload["macroRole"] as? String) ?? ""
        let attrSource = ((payload["attributeSyntax"] as? [String: Any])?["source"] as? String) ?? ""
        let declSyntax = payload["declSyntax"] as? [String: Any]
        let declSource = (declSyntax?["source"] as? String) ?? ""
        let declLocation = declSyntax?["location"] as? [String: Any]
        pendingDiagnostics = []
        currentDecl = (
            declSource,
            (declLocation?["fileName"] as? String) ?? "",
            (declLocation?["offset"] as? Int) ?? 0
        )
        let extendedType = ((payload["extendedTypeSyntax"] as? [String: Any])?["source"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let expanded: String?

        switch typeName {
        case "PeerMarkerMacro":
            expanded = nil

        case "LegacySingletonAccessorMacro":
            expanded = expandLegacySingletonAccessor(attrSource: attrSource, declSource: declSource)

        case "LegacyProviderAccessorMacro":
            expanded = expandLegacyProviderAccessor(attrSource: attrSource)

        case "ModuleMacro":
            if macroRole == "extension" {
                expanded = expandModuleExtension(extendedType: extendedType)
            } else if macroRole == "member" {
                expanded = expandModuleMember(attrSource: attrSource, declSource: declSource)
            } else {
                expanded = nil
            }

        case "InjectMacro":
            if macroRole == "extension" {
                expanded = expandInjectExtension(extendedType: extendedType)
            } else if macroRole == "member" {
                expanded = expandInjectMember(attrSource: attrSource, declSource: declSource)
            } else {
                expanded = nil
            }

        case "AppComposeMacro", "ComposeMacro":
            if macroRole == "member" {
                expanded = expandComposeMember(
                    attrSource: attrSource, declSource: declSource, isRoot: typeName == "AppComposeMacro")
            } else {
                expanded = nil
            }

        case "ModulePaletteMacro":
            if macroRole == "extension" {
                expanded = extendedType.isEmpty ? nil : "extension \(extendedType): DaggerSwift.GraphScope {}"
            } else if macroRole == "member" {
                expanded = expandModulePaletteMember(attrSource: attrSource)
            } else {
                expanded = nil
            }

        default:
            expanded = nil
        }

        var resultDict: [String: Any] = [
            "diagnostics": pendingDiagnostics
        ]
        if let expanded, !expanded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resultDict["expandedSource"] = expanded
        }
        return ["expandMacroResult": resultDict]
    }

    private static func expandModulePaletteMember(attrSource: String) -> String {
        let contractType = extractNamedTypeArgument(label: "of", from: attrSource) ?? "any DaggerSwift.GraphModule"
        let v0_1Type = extractNamedTypeArgument(label: "v0_1", from: attrSource) ?? "Never"
        let v1_0Type = extractNamedTypeArgument(label: "v1_0", from: attrSource) ?? "Never"
        let v2_0Type = extractNamedTypeArgument(label: "v2_0", from: attrSource) ?? "Never"

        return """
        public typealias Palette = DaggerSwift.ModulePalette

        public static func module(for option: DaggerSwift.ModulePalette) -> \(contractType).Type {
            switch option {
            case .v0_1: return \(v0_1Type).self
            case .v1_0: return \(v1_0Type).self
            case .v2_0: return \(v2_0Type).self
            }
        }
        """
    }

    private static func extractNamedTypeArgument(label: String, from attr: String) -> String? {
        guard let labelRange = attr.range(of: "\(label):") else { return nil }
        let afterLabel = attr[labelRange.upperBound...]
        var depth = 0
        var collected = ""
        for ch in afterLabel {
            if ch == "(" || ch == "[" || ch == "<" {
                depth += 1
                collected.append(ch)
            } else if ch == ")" || ch == "]" || ch == ">" {
                if depth == 0 {
                    break
                }
                depth -= 1
                collected.append(ch)
            } else if ch == "," && depth == 0 {
                break
            } else {
                collected.append(ch)
            }
        }
        var trimmed = collected.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix(".self") {
            trimmed = String(trimmed.dropLast(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmed.hasPrefix("(") && trimmed.hasSuffix(")") {
            trimmed = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - 1. Dagger 1 Accessor Macros (@Singleton(expr) & @Provider(expr) sobre static var)

    private static func expandLegacySingletonAccessor(attrSource: String, declSource: String) -> String {
        let expr = extractAttributeArgument(from: attrSource) ?? "fatalError()"
        let propType = extractPropertyType(from: stripComments(declSource)) ?? "Any"
        return """
        get {
            DaggerSwift.SingletonContainer.shared.resolve((\(propType)).self, initializer: { \(expr) })
        }
        """
    }

    private static func expandLegacyProviderAccessor(attrSource: String) -> String {
        let expr = extractAttributeArgument(from: attrSource) ?? "fatalError()"
        return """
        get {
            \(expr)
        }
        """
    }

    // MARK: - 2. @Module Macro (Dagger 2 Declarative Graph Module)

    private static func expandModuleExtension(extendedType: String) -> String? {
        guard !extendedType.isEmpty else { return nil }
        return """
        extension \(extendedType): DaggerSwift.GraphScope, DaggerSwift.GraphModule, DaggerSwift.Modulable {}
        """
    }

    private static func expandModuleMember(attrSource: String, declSource: String) -> String {
        let clean = stripComments(declSource)
        let moduleVersion = extractModuleVersion(from: attrSource)
        let moduleScope = extractModuleScope(from: attrSource)
        let includedModules = extractModuleIncludes(from: attrSource)
        // Módulo @MainActor (p. ej. objetos @Observable de SwiftUI): sus funciones están aisladas al
        // MainActor y el closure de register(in:) no lo está → se construyen vía ScopeContainer.onMainActor.
        let moduleHeader = clean.firstIndex(of: "{").map { String(clean[..<$0]) } ?? clean
        let moduleIsMainActor = moduleHeader.contains("@MainActor")
        let functions = parseModuleFunctions(from: clean, moduleIsMainActor: moduleIsMainActor)

        var lines: [String] = []
        lines.append("nonisolated public static let moduleVersion: String = \"\(moduleVersion)\"")
        lines.append("")
        lines.append("nonisolated public static func register(in container: DaggerSwift.ScopeContainer) {")

        if let moduleScope, !moduleScope.isEmpty {
            lines.append("    container.addCompatibleScope(\(moduleScope))")
        }

        for included in includedModules {
            lines.append("    container.addCompatibleScope(\(included).self)")
            lines.append("    \(included).register(in: container)")
        }

        for fn in functions {
            let closureParams: String
            let callArgs: String
            let fnParams = fn.parameters.filter { !$0.hasDefault }

            if fnParams.isEmpty {
                closureParams = ""
                callArgs = ""
            } else {
                let paramDecls = fnParams.enumerated().map { idx, p in
                    let pName = p.name == "_" ? "arg\(idx)" : p.name
                    return "\(pName): \(p.type)"
                }.joined(separator: ", ")
                closureParams = "(\(paramDecls)) in"
                callArgs = fnParams.enumerated().map { idx, p in
                    let pName = p.name == "_" ? "arg\(idx)" : p.name
                    if p.externalLabel == "_" {
                        return pName
                    } else {
                        return "\(p.externalLabel): \(pName)"
                    }
                }.joined(separator: ", ")
            }

            let call = fn.isThrowing
                ? "try Self.\(fn.name)(\(callArgs))"
                : "Self.\(fn.name)(\(callArgs))"
            let invocation = fn.isMainActor
                ? "try DaggerSwift.ScopeContainer.onMainActor { \(call) }"
                : call
            let returnTypeSelf = fn.returnType.contains(" ") ? "(\(fn.returnType)).self" : "\(fn.returnType).self"

            switch fn.kind {
            case .singleton:
                lines.append("    container.provideSingleton(\(returnTypeSelf)) { \(closureParams)")
                lines.append("        \(invocation)")
                lines.append("    }")

            case .scoped(let customScope):
                if let customScope, !customScope.isEmpty {
                    lines.append("    container.provideScoped(in: \(customScope), \(returnTypeSelf)) { \(closureParams)")
                    lines.append("        \(invocation)")
                    lines.append("    }")
                } else if let moduleScope, !moduleScope.isEmpty {
                    lines.append("    container.provideScoped(in: \(moduleScope), \(returnTypeSelf)) { \(closureParams)")
                    lines.append("        \(invocation)")
                    lines.append("    }")
                } else {
                    lines.append("    container.provideScoped(in: Self.self, \(returnTypeSelf)) { \(closureParams)")
                    lines.append("        \(invocation)")
                    lines.append("    }")
                }

            case .provider:
                lines.append("    container.provide(\(returnTypeSelf)) { \(closureParams)")
                lines.append("        \(invocation)")
                lines.append("    }")

            case .businessRule:
                lines.append("    container.provideBusinessRule(\(returnTypeSelf)) { \(closureParams)")
                lines.append("        \(invocation)")
                lines.append("    }")

            case .precondition(let customReason):
                let baseType = fn.returnType.hasSuffix("?")
                    ? String(fn.returnType.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                    : fn.returnType
                let baseTypeSelf = baseType.contains(" ") ? "(\(baseType)).self" : "\(baseType).self"
                let reasonLiteral = customReason ?? "\"Precondición requerida (\(baseType)) no satisfecha\""
                lines.append("    container.providePrecondition(\(baseTypeSelf), reasonIfUnmet: \(reasonLiteral)) { \(closureParams)")
                lines.append("        \(invocation)")
                lines.append("    }")
            }
        }

        lines.append("}")
        lines.append("")
        lines.append("nonisolated public static func buildGraph(including extraModules: [any DaggerSwift.GraphModule.Type] = []) -> DaggerSwift.ScopeContainer {")
        lines.append("    DaggerSwift.ScopeContainer.root(modules: [Self.self] + extraModules)")
        lines.append("}")

        return lines.joined(separator: "\n")
    }

    // MARK: - 3. @Inject Macro (Zero-Boilerplate Class/Struct Autowiring)

    private static func expandInjectExtension(extendedType: String) -> String? {
        guard !extendedType.isEmpty else { return nil }
        return """
        extension \(extendedType): DaggerSwift.Injectable {}
        """
    }

    private static func expandInjectMember(attrSource: String, declSource: String) -> String {
        let clean = stripComments(declSource)
        let scopeArg = extractInjectScopeArgument(from: attrSource)
        let hasExplicitInit = containsExplicitInitializer(in: clean)
        if hasExplicitInit, explicitInitIsAsync(in: clean) {
            diagnose(
                "@Inject: el init no puede ser async; el grafo construye de forma síncrona. Usa un init síncrono y mueve el trabajo asíncrono a un método",
                at: "init("
            )
            // Solo el stub de la conformancia: evita errores en cascada ('async' call...) sobre el diagnóstico.
            return "nonisolated public static func register(in container: DaggerSwift.ScopeContainer) {}"
        }
        let properties = parseInjectableStoredProperties(from: clean)
        // Parámetros con valor por defecto (`retries: Int = 3`) no se piden al grafo: se usa el default.
        let initParams = (hasExplicitInit ? parseExplicitInitParameters(from: clean) : properties).filter { !$0.hasDefault }

        var lines: [String] = []

        if !hasExplicitInit {
            let sig = properties.map { "\($0.name): \($0.type)" }.joined(separator: ", ")
            lines.append("public init(\(sig)) {")
            for prop in properties {
                lines.append("    self.\(prop.name) = \(prop.name)")
            }
            lines.append("}")
            lines.append("")
        }

        // Solo el encabezado del tipo (atributos + `class/struct/actor Nombre: ...`) decide el aislamiento:
        // un miembro `@MainActor private var x` NO hace al tipo @MainActor.
        let header = clean.firstIndex(of: "{").map { String(clean[..<$0]) } ?? clean
        let isClassType = header.contains("class ")
        let isMainActor = header.contains("@MainActor")
        let initModifier = isClassType ? "public convenience init" : "public init"
        let resolveArgs = initParams.map { p in
            let label = p.externalLabel == "_" ? "" : "\(p.externalLabel): "
            let typeSelf = p.type.contains(" ") ? "(\(p.type)).self" : "\(p.type).self"
            return "\(label)try container.resolve(\(typeSelf))"
        }.joined(separator: ", ")

        lines.append("\(initModifier)(from container: DaggerSwift.ScopeContainer) throws {")
        if initParams.isEmpty {
            lines.append("    self.init()")
        } else {
            lines.append("    self.init(\(resolveArgs))")
        }
        lines.append("}")
        lines.append("")

        let closureParams: String
        let callArgs: String
        if initParams.isEmpty {
            closureParams = ""
            callArgs = ""
        } else {
            let pDecls = initParams.enumerated().map { idx, p in
                let pName = p.name == "_" ? "arg\(idx)" : p.name
                return "\(pName): \(p.type)"
            }.joined(separator: ", ")
            closureParams = "(\(pDecls)) in"
            callArgs = initParams.enumerated().map { idx, p in
                let pName = p.name == "_" ? "arg\(idx)" : p.name
                return p.externalLabel == "_" ? pName : "\(p.externalLabel): \(pName)"
            }.joined(separator: ", ")
        }

        // Tipos @MainActor: si se resuelven fuera del hilo principal se lanza `GraphError.mainActorRequired`
        // en lugar de crashear con `MainActor.assumeIsolated`.
        let makeInstance = isMainActor
            ? "try DaggerSwift.ScopeContainer.onMainActor { Self(\(callArgs)) }"
            : "Self(\(callArgs))"

        lines.append("nonisolated public static func register(in container: DaggerSwift.ScopeContainer) {")
        if let scopeArg, !scopeArg.isEmpty {
            lines.append("    container.provideScoped(in: \(scopeArg), Self.self) { \(closureParams)")
            lines.append("        \(makeInstance)")
            lines.append("    }")
        } else {
            lines.append("    container.provide(Self.self) { \(closureParams)")
            lines.append("        \(makeInstance)")
            lines.append("    }")
        }
        lines.append("}")
        lines.append("")
        lines.append("nonisolated public static func resolve(in container: DaggerSwift.ScopeContainer) throws -> Self {")
        lines.append("    try container.resolve(Self.self)")
        lines.append("}")

        return lines.joined(separator: "\n")
    }

    // MARK: - 4. @AppCompose / @Compose (RootComposer con resolución jerárquica)

    /// `@AppCompose(M.self)` (raíz) y `@Compose(S.self)` (scope hijo). Cada `let` sin valor inicial se
    /// resuelve del contenedor de su nivel; cada tipo anidado con `@Compose` recibe un `openX()`.
    private static func expandComposeMember(attrSource: String, declSource: String, isRoot: Bool) -> String {
        let clean = stripComments(declSource)
        let macroName = isRoot ? "@AppCompose" : "@Compose"
        guard let target = extractAttributeArgument(from: attrSource)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !target.isEmpty else {
            diagnose("\(macroName): falta el módulo o scope, p. ej. \(macroName)(AppModule.self)", at: nil)
            return ""
        }
        if containsExplicitInitializer(in: topLevelSource(of: clean)) {
            diagnose("\(macroName): el tipo ya declara un init; la macro no genera el suyo", at: "init(")
            return ""
        }
        let properties = parseInjectableStoredProperties(from: clean)
        let children = parseComposeChildren(from: clean)

        var lines: [String] = []
        lines.append("/// Contenedor de este nivel del grafo. Lo abre el `init`; `close()` lo cierra.")
        lines.append("public let graph: DaggerSwift.ScopeContainer")
        lines.append("")
        if isRoot {
            lines.append("/// Arranque: abre la raíz con \(target) y resuelve cada propiedad. Lanza `GraphError` si falta")
            lines.append("/// algo: el único `catch` del grafo va en quien crea el compositor.")
            lines.append("public init() throws {")
            lines.append("    let graph = DaggerSwift.ScopeContainer.root(modules: [\(target)])")
        } else {
            lines.append("/// Abre este scope bajo `parent` y resuelve cada propiedad. Lanza `GraphError` si falta algo o")
            lines.append("/// una `@Precondition` no se cumple (antes de construir nada).")
            lines.append("public init(parent: DaggerSwift.ScopeContainer) throws {")
            lines.append("    let graph = parent.makeChildScope(for: \(target))")
        }
        lines.append("    self.graph = graph")
        for prop in properties {
            let typeSelf = prop.type.contains(" ") ? "(\(prop.type)).self" : "\(prop.type).self"
            lines.append("    self.\(prop.name) = try graph.resolve(\(typeSelf))")
        }
        lines.append("}")
        lines.append("")
        lines.append("/// Cierra este nivel y sus hijos en cascada. Devuelve los tipos que seguían retenidos.")
        lines.append("@discardableResult")
        lines.append("public func close() -> [String] {")
        lines.append("    graph.teardown()")
        lines.append("}")
        for child in children {
            lines.append("")
            lines.append("/// Abre el scope hijo `\(child)`. Quien guarda el valor es dueño de su ciclo de vida.")
            lines.append("public func open\(child)() throws -> \(child) {")
            lines.append("    try \(child)(parent: graph)")
            lines.append("}")
        }
        return lines.joined(separator: "\n")
    }

    /// Nombres de los tipos anidados (struct/class) marcados con `@Compose(...)` en el primer nivel del cuerpo.
    private static func parseComposeChildren(from source: String) -> [String] {
        let body = extractOuterBracesBody(from: source)
        var names: [String] = []
        for decl in splitTopLevelDeclarations(in: body) {
            guard decl.contains("@Compose") else { continue }
            let header = decl.firstIndex(of: "{").map { String(decl[..<$0]) } ?? decl
            let tokens = header.split(whereSeparator: { $0.isWhitespace || $0 == ":" }).map(String.init)
            guard let kw = tokens.lastIndex(where: { $0 == "struct" || $0 == "class" }),
                  kw + 1 < tokens.count else { continue }
            names.append(tokens[kw + 1])
        }
        return names
    }

    /// El cuerpo del tipo sin los cuerpos de sus tipos anidados (para no confundir un `init` de un hijo con el propio).
    private static func topLevelSource(of source: String) -> String {
        let body = extractOuterBracesBody(from: source)
        return splitTopLevelDeclarations(in: body)
            .filter { !($0.contains("struct ") || $0.contains("class ") || $0.contains("enum ") || $0.contains("actor ")) }
            .joined(separator: "\n")
    }

    // MARK: - Helpers de Parsing Sintáctico Ligero

    private enum ModuleNodeKind {
        case singleton
        case scoped(String?)
        case provider
        case businessRule
        case precondition(String?)

        var attributeName: String {
            switch self {
            case .singleton: return "@Singleton"
            case .scoped: return "@Scoped"
            case .provider: return "@Provider"
            case .businessRule: return "@BusinessRule"
            case .precondition: return "@Precondition"
            }
        }
    }

    private struct ParsedParam {
        let externalLabel: String
        let name: String
        let type: String
        /// `x: Int = 3`: el grafo NO lo resuelve; se usa el valor por defecto.
        var hasDefault: Bool = false
    }

    private struct ParsedFunction {
        let kind: ModuleNodeKind
        let name: String
        let parameters: [ParsedParam]
        let returnType: String
        let isThrowing: Bool
        /// `@MainActor` en la función (o en el módulo, salvo `nonisolated`): se construye vía onMainActor.
        var isMainActor: Bool = false
    }

    private static func stripComments(_ source: String) -> String {
        var result = ""
        var i = source.startIndex
        var inString = false
        var escaped = false

        while i < source.endIndex {
            let c = source[i]
            let nextIdx = source.index(after: i)
            let nextChar: Character? = nextIdx < source.endIndex ? source[nextIdx] : nil

            if inString {
                result.append(c)
                if escaped {
                    escaped = false
                } else if c == "\\" {
                    escaped = true
                } else if c == "\"" {
                    inString = false
                }
                i = nextIdx
                continue
            }

            if c == "\"" {
                inString = true
                result.append(c)
                i = nextIdx
                continue
            }

            if c == "/", nextChar == "/" {
                // Skip line comment
                while i < source.endIndex, source[i] != "\n" {
                    i = source.index(after: i)
                }
                continue
            }

            if c == "/", nextChar == "*" {
                // Skip block comment
                i = source.index(after: nextIdx)
                while i < source.endIndex {
                    let n = source.index(after: i)
                    if source[i] == "*", n < source.endIndex, source[n] == "/" {
                        i = source.index(after: n)
                        break
                    }
                    i = n
                }
                continue
            }

            result.append(c)
            i = nextIdx
        }
        return result
    }

    private static func extractOuterBracesBody(from source: String) -> String {
        guard let firstBrace = source.firstIndex(of: "{"),
              let lastBrace = source.lastIndex(of: "}"),
              firstBrace < lastBrace else {
            return source
        }
        return String(source[source.index(after: firstBrace)..<lastBrace])
    }

    private static func extractAttributeArgument(from attrSource: String) -> String? {
        let clean = stripComments(attrSource)
        guard let open = clean.firstIndex(of: "("),
              let close = clean.lastIndex(of: ")"),
              open < close else {
            return nil
        }
        var arg = String(clean[clean.index(after: open)..<close])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if arg.hasPrefix("wrappedValue:") {
            arg = String(arg.dropFirst("wrappedValue:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return arg
    }

    private static func extractInjectScopeArgument(from attrSource: String) -> String? {
        guard let arg = extractAttributeArgument(from: attrSource), !arg.isEmpty else {
            return nil
        }
        if let colon = arg.firstIndex(of: ":") {
            return String(arg[arg.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return arg
    }

    private static func extractModuleVersion(from attrSource: String) -> String {
        guard let rawArgs = extractAttributeArgument(from: attrSource), !rawArgs.isEmpty else {
            return "1.0"
        }
        for part in splitByTopLevelComma(rawArgs) {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("scope:") || trimmed.hasPrefix("includes:") {
                continue
            }
            if trimmed.hasPrefix("version:") {
                return String(trimmed.dropFirst("version:".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \""))
            }
            if !trimmed.contains(":") {
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: " \""))
            }
        }
        return "1.0"
    }

    private static func extractModuleScope(from attrSource: String) -> String? {
        guard let rawArgs = extractAttributeArgument(from: attrSource), !rawArgs.isEmpty else {
            return nil
        }
        for part in splitByTopLevelComma(rawArgs) {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("scope:") {
                let value = String(trimmed.dropFirst("scope:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }

    private static func extractModuleIncludes(from attrSource: String) -> [String] {
        guard let rawArgs = extractAttributeArgument(from: attrSource), !rawArgs.isEmpty else {
            return []
        }
        for part in splitByTopLevelComma(rawArgs) {
            var trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("includes:") {
                trimmed = String(trimmed.dropFirst("includes:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    trimmed = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return splitByTopLevelComma(trimmed).compactMap { item in
                    var cleaned = item.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.hasSuffix(".self") {
                        cleaned = String(cleaned.dropLast(".self".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return cleaned.isEmpty ? nil : cleaned
                }
            }
        }
        return []
    }

    private static func extractPropertyType(from declSource: String) -> String? {
        guard let varRange = declSource.range(of: "var ") ?? declSource.range(of: "let ") else {
            return nil
        }
        let afterVar = declSource[varRange.upperBound...]
        guard let colon = afterVar.firstIndex(of: ":") else { return nil }
        let afterColon = afterVar[afterVar.index(after: colon)...]
        let endIdx = afterColon.firstIndex(where: { $0 == "{" || $0 == "=" || $0 == "\n" }) ?? afterColon.endIndex
        return String(afterColon[..<endIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseModuleFunctions(from source: String, moduleIsMainActor: Bool = false) -> [ParsedFunction] {
        let body = extractOuterBracesBody(from: source)
        var results: [ParsedFunction] = []

        // Dividir declaraciones top-level dentro del cuerpo del módulo
        let tokens = splitTopLevelDeclarations(in: body)
        for decl in tokens {
            guard decl.contains("func ") else { continue }
            guard let kind = detectNodeKind(in: decl) else { continue }
            guard let funcRange = decl.range(of: "func ") else { continue }

            let afterFunc = String(decl[funcRange.upperBound...])
            guard let openParen = afterFunc.firstIndex(of: "(") else { continue }
            let funcName = String(afterFunc[..<openParen]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard let closeParen = findMatchingParen(in: afterFunc, from: openParen) else { continue }
            let paramsString = String(afterFunc[afterFunc.index(after: openParen)..<closeParen])
            let params = parseParameterList(paramsString)

            let afterParams = String(afterFunc[afterFunc.index(after: closeParen)...])
            guard let arrowRange = afterParams.range(of: "->") else {
                diagnose(
                    "\(kind.attributeName) '\(funcName)()' necesita un tipo de retorno (-> Tipo): el grafo registra cada función por el tipo que devuelve",
                    at: "func \(funcName)"
                )
                continue
            }
            let beforeArrow = String(afterParams[..<arrowRange.lowerBound])
            let isThrowing = beforeArrow.contains("throws")
            if beforeArrow.contains("async") {
                diagnose(
                    "\(kind.attributeName) '\(funcName)()' no puede ser async: el grafo construye las dependencias de forma síncrona. Hazla síncrona, o resuelve el valor asíncrono fuera del grafo (p. ej. en el Coordinator) y pásalo con bindInstance",
                    at: "func \(funcName)"
                )
                continue
            }

            let afterArrow = String(afterParams[arrowRange.upperBound...])
            let returnEnd = afterArrow.firstIndex(of: "{") ?? afterArrow.endIndex
            let returnType = String(afterArrow[..<returnEnd]).trimmingCharacters(in: .whitespacesAndNewlines)

            let funcHeader = String(decl[..<funcRange.lowerBound])
            let isMainActor = funcHeader.contains("@MainActor")
                || (moduleIsMainActor && !funcHeader.contains("nonisolated"))
            results.append(
                ParsedFunction(
                    kind: kind,
                    name: funcName,
                    parameters: params,
                    returnType: returnType,
                    isThrowing: isThrowing,
                    isMainActor: isMainActor
                )
            )
        }
        return results
    }

    private static func detectNodeKind(in decl: String) -> ModuleNodeKind? {
        guard let funcIdx = decl.range(of: "func ")?.lowerBound else { return nil }
        let header = String(decl[..<funcIdx])

        if header.contains("@Singleton") {
            return .singleton
        }
        if let r = header.range(of: "@Scoped") {
            let tail = String(header[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if tail.hasPrefix("("),
               let open = tail.firstIndex(of: "("),
               let close = findMatchingParen(in: tail, from: open) {
                let arg = String(tail[tail.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
                return .scoped(arg.isEmpty ? nil : arg)
            }
            return .scoped(nil)
        }
        if header.contains("@Provider") {
            return .provider
        }
        if header.contains("@BusinessRule") {
            return .businessRule
        }
        if let r = header.range(of: "@Precondition") {
            let tail = String(header[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if tail.hasPrefix("("),
               let open = tail.firstIndex(of: "("),
               let close = findMatchingParen(in: tail, from: open) {
                let arg = String(tail[tail.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines)
                return .precondition(arg.isEmpty ? nil : arg)
            }
            return .precondition(nil)
        }
        return nil
    }

    private static func containsExplicitInitializer(in source: String) -> Bool {
        let body = extractOuterBracesBody(from: source)
        let decls = splitTopLevelDeclarations(in: body)
        return decls.contains { d in
            let trimmed = d.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("init(") || trimmed.contains(" init(") || trimmed.contains("\ninit(")
        }
    }

    private static func explicitInitIsAsync(in source: String) -> Bool {
        let body = extractOuterBracesBody(from: source)
        for d in splitTopLevelDeclarations(in: body) {
            guard let initRange = d.range(of: "init(") else { continue }
            let fromParen = String(d[d.index(before: initRange.upperBound)...])
            guard let close = findMatchingParen(in: fromParen, from: fromParen.startIndex) else { continue }
            let afterParams = fromParen[fromParen.index(after: close)...]
            let header = afterParams.prefix { $0 != "{" }
            return header.contains("async")
        }
        return false
    }

    private static func parseExplicitInitParameters(from source: String) -> [ParsedParam] {
        let body = extractOuterBracesBody(from: source)
        let decls = splitTopLevelDeclarations(in: body)
        for d in decls {
            if let initRange = d.range(of: "init(") {
                let fromParen = String(d[d.index(before: initRange.upperBound)...])
                let open = fromParen.startIndex
                if let close = findMatchingParen(in: fromParen, from: open) {
                    let inside = String(fromParen[fromParen.index(after: open)..<close])
                    return parseParameterList(inside)
                }
            }
        }
        return []
    }

    private static func parseInjectableStoredProperties(from source: String) -> [ParsedParam] {
        let body = extractOuterBracesBody(from: source)
        let decls = splitTopLevelDeclarations(in: body)
        var props: [ParsedParam] = []

        for d in decls {
            let trimmed = d.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("static ") || trimmed.contains("func ") || trimmed.contains("init(") {
                continue
            }
            if trimmed.contains("@Published") || trimmed.contains("@State") || trimmed.contains("@Binding") {
                continue
            }
            // Ignorar propiedades con valor por defecto (=) o bloques computados ({)
            if trimmed.contains("=") || trimmed.contains("{") {
                continue
            }
            guard let range = trimmed.range(of: "let ") ?? trimmed.range(of: "var ") else {
                continue
            }
            let afterKeyword = String(trimmed[range.upperBound...])
            // `let a, b: Int` (ambos Int) y `let a: Int, b: String` (cada uno con su tipo).
            var pendingNames: [String] = []
            for part in splitByTopLevelComma(afterKeyword) {
                let piece = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let colon = piece.firstIndex(of: ":") else {
                    if !piece.isEmpty { pendingNames.append(piece) }
                    continue
                }
                let propName = String(piece[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
                var propType = String(piece[piece.index(after: colon)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if propType.hasPrefix("@escaping ") {
                    propType = String(propType.dropFirst("@escaping ".count))
                }
                for name in pendingNames + [propName] {
                    props.append(ParsedParam(externalLabel: name, name: name, type: propType))
                }
                pendingNames.removeAll()
            }
        }
        return props
    }

    private static func parseParameterList(_ raw: String) -> [ParsedParam] {
        let parts = splitByTopLevelComma(raw)
        var params: [ParsedParam] = []
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let colon = trimmed.firstIndex(of: ":") else { continue }
            let lhs = String(trimmed[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            var rhs = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)

            // Quitar valor por defecto si existe (y recordarlo: ese parámetro no se resuelve del grafo)
            var hasDefault = false
            if let eq = rhs.firstIndex(of: "=") {
                rhs = String(rhs[..<eq]).trimmingCharacters(in: .whitespacesAndNewlines)
                hasDefault = true
            }
            if rhs.hasPrefix("@escaping ") {
                rhs = String(rhs.dropFirst("@escaping ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let nameTokens = lhs.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            let externalLabel = nameTokens.first ?? "_"
            let internalName = nameTokens.last ?? externalLabel
            params.append(ParsedParam(externalLabel: externalLabel, name: internalName, type: rhs, hasDefault: hasDefault))
        }
        return params
    }

    private static func findMatchingParen(in text: String, from openIdx: String.Index) -> String.Index? {
        var depth = 0
        var i = openIdx
        while i < text.endIndex {
            let c = text[i]
            if c == "(" {
                depth += 1
            } else if c == ")" {
                depth -= 1
                if depth == 0 {
                    return i
                }
            }
            i = text.index(after: i)
        }
        return nil
    }

    private static func splitByTopLevelComma(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var parenDepth = 0
        var angleDepth = 0
        var bracketDepth = 0

        for c in text {
            switch c {
            case "(": parenDepth += 1; current.append(c)
            case ")": parenDepth = max(0, parenDepth - 1); current.append(c)
            case "<": angleDepth += 1; current.append(c)
            case ">": angleDepth = max(0, angleDepth - 1); current.append(c)
            case "[": bracketDepth += 1; current.append(c)
            case "]": bracketDepth = max(0, bracketDepth - 1); current.append(c)
            case "," where parenDepth == 0 && angleDepth == 0 && bracketDepth == 0:
                items.append(current)
                current = ""
            default:
                current.append(c)
            }
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(current)
        }
        return items
    }

    private static func splitTopLevelDeclarations(in body: String) -> [String] {
        var decls: [String] = []
        var current = ""
        var braceDepth = 0
        var parenDepth = 0

        for c in body {
            if c == "(" {
                parenDepth += 1
                current.append(c)
            } else if c == ")" {
                parenDepth = max(0, parenDepth - 1)
                current.append(c)
            } else if c == "{" {
                braceDepth += 1
                current.append(c)
            } else if c == "}" {
                braceDepth = max(0, braceDepth - 1)
                current.append(c)
                if braceDepth == 0 && parenDepth == 0 {
                    decls.append(current)
                    current = ""
                }
            } else if c == "\n" && braceDepth == 0 && parenDepth == 0 {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                // Si la línea actual es una propiedad (let/var) completa sin llaves, la separamos
                if (trimmed.contains("let ") || trimmed.contains("var ")) && !trimmed.contains("func ") {
                    decls.append(current)
                    current = ""
                } else {
                    current.append(c)
                }
            } else {
                current.append(c)
            }
        }
        if !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            decls.append(current)
        }
        return decls
    }
}
