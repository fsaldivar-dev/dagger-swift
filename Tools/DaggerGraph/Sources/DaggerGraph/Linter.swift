//
//  Linter.swift
//  dagger-graph
//
//  `dagger-graph lint`: las prácticas que compilan pero rompen la resolución explícita
//  (docs/QUICKSTART.md §5). Cada regla tiene id, severidad por defecto y referencia al Quick Start;
//  la severidad se ajusta en `dagger-graph.json` y un sitio se silencia con `// dagger-graph: allow <id>`.
//

import Foundation

/// `dagger-graph.json` en el directorio analizado o en alguno de sus padres.
struct LintConfig: Codable, Sendable {
    /// Activa el linter (también `--lint` en la CLI).
    var lint: Bool = false
    /// Fragmentos de ruta que cuentan como raíz de composición o coordinador (donde sí va el `catch` de
    /// `GraphError`). Los archivos que declaran un `@AppCompose` / `@Compose` lo son siempre.
    var rootFiles: [String] = []
    /// Severidad por regla: `"error"`, `"warning"` u `"off"`.
    var rules: [String: String] = [:]

    static let fileName = "dagger-graph.json"

    /// Busca el archivo subiendo desde cada directorio analizado. Devuelve la config y su ruta.
    static func discover(near directories: [String]) -> (LintConfig, String)? {
        for dir in directories {
            var url = URL(fileURLWithPath: dir).standardizedFileURL
            for _ in 0..<8 {
                let candidate = url.appendingPathComponent(fileName)
                if let data = FileManager.default.contents(atPath: candidate.path),
                   let config = try? JSONDecoder().decode(LintConfig.self, from: data) {
                    return (config, candidate.path)
                }
                let parent = url.deletingLastPathComponent()
                if parent.path == url.path { break }
                url = parent
            }
        }
        return nil
    }
}

enum LintRule: String, CaseIterable, Sendable {
    case resolveOutsideCompositor = "resolve-outside-compositor"
    case containerInFeature = "container-in-feature"
    case moduleStaticResolve = "module-static-resolve"
    case dynamicRegistration = "dynamic-registration"
    case optionalTry = "optional-try"
    case catchOutsideRoot = "catch-outside-root"
    case sharedInModule = "shared-in-module"
    case staticCompositor = "static-compositor"
    case injectNonFinal = "inject-non-final"
    case injectDotInit = "inject-dot-init"
    case providerAsLet = "provider-as-let"
    case letAsProvider = "let-as-provider"

    var defaultSeverity: Diagnostic.Severity {
        switch self {
        case .resolveOutsideCompositor, .moduleStaticResolve, .optionalTry, .staticCompositor,
             .injectNonFinal, .providerAsLet:
            return .error
        case .containerInFeature, .dynamicRegistration, .catchOutsideRoot, .sharedInModule,
             .injectDotInit, .letAsProvider:
            return .warning
        }
    }

    var quickStart: String {
        switch self {
        case .resolveOutsideCompositor: return "5.1"
        case .containerInFeature: return "5.2"
        case .moduleStaticResolve: return "5.3"
        case .dynamicRegistration: return "5.4"
        case .optionalTry: return "5.5"
        case .catchOutsideRoot: return "5.6"
        case .sharedInModule: return "5.7"
        case .staticCompositor: return "5.8"
        case .injectNonFinal, .injectDotInit: return "5.10"
        case .providerAsLet, .letAsProvider: return "5.11"
        }
    }
}

extension Validator {
    private func severity(_ rule: LintRule, config: LintConfig) -> Diagnostic.Severity? {
        switch config.rules[rule.rawValue]?.lowercased() {
        case "off", "none", "false": return nil
        case "error": return .error
        case "warning", "warn": return .warning
        default: return rule.defaultSeverity
        }
    }

    private func diag(_ rule: LintRule, _ file: String, _ loc: Loc, _ message: String, config: LintConfig) -> [Diagnostic]? {
        guard let sev = severity(rule, config: config) else { return nil }
        return [Diagnostic(
            file: file, loc: loc, severity: sev,
            message: "[lint \(rule.rawValue)] \(message) (Quick Start §\(rule.quickStart); silenciar: // dagger-graph: allow \(rule.rawValue))"
        )]
    }

    func lintDiagnostics(config: LintConfig) -> [[Diagnostic]] {
        var out: [[Diagnostic]] = []
        let composeFiles = Set(composes.map(\.file))
        let composeNames = Set(composes.map(\.fact.name)).union(composes.compactMap { $0.fact.name.split(separator: ".").last.map(String.init) })
        func isRootFile(_ file: String) -> Bool {
            composeFiles.contains(file) || config.rootFiles.contains { !$0.isEmpty && file.contains($0) }
        }
        func isTestFile(_ file: String) -> Bool {
            file.contains("/Tests/") || file.contains("/Test/") || file.hasSuffix("Tests.swift")
        }
        func moduleExists(_ name: String) -> Bool {
            modules[name] != nil || modules.keys.contains { $0.split(separator: ".").last.map(String.init) == name }
        }

        func suppressed(_ site: LintSite, _ rule: LintRule) -> Bool {
            guard let allowed = site.allowed else { return false }
            return allowed.isEmpty || allowed.contains(rule.rawValue) || allowed.contains("all")
        }
        func siteDiag(_ rule: LintRule, _ site: LintSite, _ file: String, _ message: String) -> [Diagnostic]? {
            suppressed(site, rule) ? nil : diag(rule, file, site.loc, message, config: config)
        }

        for (file, site) in lintSites {
            switch site.kind {
            case .resolveCall:
                guard !site.inCompositor, !isTestFile(file) else { continue }
                let what = site.type.map { "'\($0)'" } ?? "una dependencia"
                if let d = siteDiag(.resolveOutsideCompositor, site, file,
                    "caja mágica: se pide \(what) al contenedor fuera de un compositor; la dependencia va en el init (@Inject) o llega por Environment, y `resolve` solo lo llama el código generado por @AppCompose / @Compose") { out.append(d) }

            case .moduleStaticResolve:
                guard let receiver = site.type else { continue }
                if moduleExists(receiver) {
                    if isTestFile(file) { continue }
                    if let d = siteDiag(.moduleStaticResolve, site, file,
                        "`\(receiver).resolve(…)` resuelve contra un árbol escondido de la librería, no contra tu compositor: tendrás dos instancias de cada singleton") { out.append(d) }
                } else if !site.inCompositor, !isTestFile(file), receiver != "ScopeContainer", receiver != "DaggerSwift" {
                    if let d = siteDiag(.resolveOutsideCompositor, site, file,
                        "caja mágica: `\(site.text)` fuera de un compositor; la dependencia va en el init (@Inject) o llega por Environment") { out.append(d) }
                }

            case .containerUse:
                guard !site.inCompositor, !isRootFile(file), !isTestFile(file) else { continue }
                if let d = siteDiag(.containerInFeature, site, file,
                    "`ScopeContainer` fuera de un compositor: quien recibe el contenedor puede pedir cualquier cosa (service locator). Publícalo solo desde la raíz (`\\.graphScope`) o pasa la dependencia concreta") { out.append(d) }

            case .optionalTry:
                if let d = siteDiag(.optionalTry, site, file,
                    "`try?` sobre el grafo convierte un binding faltante en un `nil` silencioso; si puede faltar por estado es una @Precondition y el compositor lanza unmetPrecondition") { out.append(d) }

            case .graphErrorCatch:
                guard !isRootFile(file), !isTestFile(file) else { continue }
                if let d = siteDiag(.catchOutsideRoot, site, file,
                    "`catch GraphError` fuera de la raíz o el coordinador: la política de errores del grafo va en un solo sitio (declara el archivo en `rootFiles` de dagger-graph.json si lo es)") { out.append(d) }

            case .sharedReturn:
                if let d = siteDiag(.sharedInModule, site, file,
                    "\(site.type ?? site.text) devuelve `.shared`: el grafo no crea el objeto, solo lo registra; mientras exista `.shared` cualquiera puede saltarse el grafo. Vale como paso de migración (silenciar) pero no como destino") { out.append(d) }

            case .staticTypeInit:
                guard let type = site.type, composeNames.contains(type) else { continue }
                if let d = siteDiag(.staticCompositor, site, file,
                    "el compositor `\(type)` en un `static`: cualquier archivo puede pedirle objetos y vuelve a ser un service locator; lo posee la raíz (App, AppDelegate, Coordinator) y publica hacia abajo") { out.append(d) }

            case .injectNonFinal:
                if let d = siteDiag(.injectNonFinal, site, file,
                    "@Inject sobre una clase no `final`: la macro genera `Self(...)`, que exige `required init`; márcala `final`") { out.append(d) }

            case .injectDotInit:
                if let d = siteDiag(.injectDotInit, site, file,
                    "`.init(` como valor por defecto dentro de un tipo @Inject: la macro lo confunde con el init del tipo; escribe `Tipo()`") { out.append(d) }
            }
        }

        // 5.4: registro imperativo fuera de tests.
        for (file, reg) in dynamic where !isTestFile(file) {
            if let d = diag(.dynamicRegistration, file, reg.loc,
                "`\(reg.call)(…)` registra a mano: invisible para dagger-graph y para quien lee los módulos; usa un @Module alternativo o `includes:`", config: config) { out.append(d) }
        }

        // 5.11: `let x: T` vs `let x: Provider<T>` según cómo se provee `T`.
        for (file, fact) in composes {
            for m in fact.members {
                guard let idx = providerIndices(for: m.type), !idx.isEmpty else { continue }
                let kinds = Set(idx.map { nodes[$0].binding.kind })
                let perCall: Set<BindingKind> = [.provider, .businessRule, .inject]
                let perScope: Set<BindingKind> = [.singleton, .scoped]
                if !m.isProvider, kinds.isSubset(of: perCall), !kinds.isEmpty {
                    let how = kinds.contains(.businessRule) ? "@BusinessRule (se reevalúa al consultar)" : kinds.contains(.provider) ? "@Provider (una instancia por petición)" : "@Inject sin scope (una instancia por petición)"
                    if let d = diag(.providerAsLet, file, m.loc,
                        "`let \(m.name): \(m.type)` en \(fact.name) se resuelve una sola vez al abrir el nivel, pero '\(m.type)' es \(how); declara `Provider<\(m.type)>`", config: config) { out.append(d) }
                } else if m.isProvider, kinds.isSubset(of: perScope), !kinds.isEmpty {
                    if let d = diag(.letAsProvider, file, m.loc,
                        "`Provider<\(m.type)>` en \(fact.name): '\(m.type)' es \(kinds.contains(.singleton) ? "@Singleton" : "@Scoped") (una instancia por nivel); basta `let \(m.name): \(m.type)`", config: config) { out.append(d) }
                }
            }
        }
        return out
    }
}
