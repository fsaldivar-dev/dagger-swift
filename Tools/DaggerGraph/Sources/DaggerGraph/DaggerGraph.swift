//
//  DaggerGraph.swift
//  dagger-graph
//
//  Uso: dagger-graph [--timings] [--no-cache] [--cache <ruta>] <dir> [<dir> ...]
//
//  Pipeline:
//  0. Enumerar .swift + stat (mtime/size). Si nada cambió vs. el caché → imprime diagnósticos cacheados y sale.
//  1. Prefiltro por bytes: solo archivos con "@Inject", "@Module" o registros dinámicos se parsean.
//  2. Parseo con SwiftParser en paralelo (TaskGroup).
//  3. Extracción de hechos en paralelo.
//  4. Validación global (faltantes, ciclos, scope).
//

import Foundation
import SwiftParser
import SwiftSyntax

// MARK: - Caché

struct CacheEntry: Codable, Sendable {
    var mtime: Double
    var size: Int
    var hash: UInt64
    var relevant: Bool
    var facts: FileFacts?
}

struct CacheFile: Codable {
    static let currentVersion = 4
    var version = CacheFile.currentVersion
    var roots: [String] = []
    var entries: [String: CacheEntry] = [:]
    var diagnostics: [Diagnostic]?
}

enum Hashing {
    /// FNV-1a 64 sobre el contenido (sin dependencias, suficiente para detectar cambios).
    static func fnv1a(_ data: Data) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        data.withUnsafeBytes { raw in
            for byte in raw.bindMemory(to: UInt8.self) {
                h ^= UInt64(byte)
                h &*= 0x100000001b3
            }
        }
        return h
    }
}

// MARK: - Timings

final class Clock {
    private var marks: [(String, Double)] = []
    private var last = Clock.now()
    private let start = Clock.now()
    static func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000 }
    func mark(_ label: String) {
        let t = Clock.now()
        marks.append((label, t - last))
        last = t
    }
    func report(parsed: Int, relevant: Int, total: Int, reused: Int, fastPath: Bool) -> String {
        func row(_ l: String, _ ms: Double) -> String {
            "  " + l.padding(toLength: 12, withPad: " ", startingAt: 0) + String(format: "%8.2f ms", ms)
        }
        var lines = marks.map { row($0.0, $0.1) }
        lines.append(row("total", Clock.now() - start))
        lines.append("  archivos: \(total) .swift · \(relevant) relevantes · \(parsed) parseados · \(reused) desde caché\(fastPath ? " · fast-path (sin cambios)" : "")")
        return "[dagger-graph timings]\n" + lines.joined(separator: "\n")
    }
}

// MARK: - Main

@main
struct DaggerGraphCommand {
    static let markers: [Data] = ["@Inject", "@Module", "bindInstance(", ".provide"].map { Data($0.utf8) }
    static let skipDirs: Set<String> = ["DerivedData", "Pods", "Carthage", "node_modules"]

    struct ScannedFile: Sendable {
        let path: String
        let mtime: Double
        let size: Int
    }

    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        let generateMode = args.first == "generate"
        let manifestMode = args.first == "manifest"
        if generateMode || manifestMode { args.removeFirst() }
        let timings = args.contains("--timings")
        let useCache = !args.contains("--no-cache")
        func option(_ name: String) -> String? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            let value = args[i + 1]
            args.removeSubrange(i...(i + 1))
            return value
        }
        let cachePath = option("--cache") ?? ".build/dagger-graph-cache.json"
        // Archivo Swift de salida para el build-tool plugin (se escribe solo si cambió).
        let outputSwift = option("--output-swift")
        // generate
        let generateOut = option("--out")
        let rootsIn = option("--roots-in")
        let targetModule = option("--target-module")
        var extraImports: [String] = []
        while let m = option("--import") { extraImports.append(m) }
        // Multi-paquete: manifiestos externos que se unen al grafo (repetible).
        var manifestPaths: [String] = []
        while let m = option("--manifest") { manifestPaths.append(m) }
        let manifestName = option("--name")
        if manifestMode && (generateOut == nil || manifestName == nil) {
            FileHandle.standardError.write(Data("uso: dagger-graph manifest --name <Paquete> --out <archivo.json> <dir>...\n".utf8))
            exit(2)
        }
        if generateMode && generateOut == nil {
            FileHandle.standardError.write(Data("uso: dagger-graph generate --out <dir> [--roots-in <prefijo>] [--target-module M] [--import M]... <dir>...\n".utf8))
            exit(2)
        }
        let roots = args.filter { !$0.hasPrefix("--") }
        guard !roots.isEmpty else {
            FileHandle.standardError.write(Data("uso: dagger-graph [--timings] [--no-cache] [--cache <ruta>] [--output-swift <ruta>] <dir> [<dir> ...]\n".utf8))
            exit(2)
        }

        let clock = Clock()

        // 0. Enumeración + stat
        // Directorios solapados (p. ej. desde Xcode) no deben duplicar archivos.
        var seenPaths = Set<String>()
        let files = roots.flatMap(scan).filter {
            seenPaths.insert(URL(fileURLWithPath: $0.path).standardizedFileURL.path).inserted
        }
        var cache = CacheFile()
        if useCache, let data = FileManager.default.contents(atPath: cachePath),
           let decoded = try? JSONDecoder().decode(CacheFile.self, from: data),
           decoded.version == CacheFile.currentVersion, decoded.roots == roots {
            cache = decoded
        }
        cache.roots = roots

        let unchanged = cache.diagnostics != nil
            && cache.entries.count == files.count
            && files.allSatisfy { f in cache.entries[f.path].map { $0.mtime == f.mtime && $0.size == f.size } ?? false }
        clock.mark("scan")

        if unchanged, !generateMode, !manifestMode, manifestPaths.isEmpty, let diags = cache.diagnostics {
            emit(diags)
            if let outputSwift { writeStamp(outputSwift, diagnostics: diags, files: cache.entries.count) }
            if timings {
                let relevant = cache.entries.values.filter(\.relevant).count
                FileHandle.standardError.write(Data((clock.report(parsed: 0, relevant: relevant, total: files.count, reused: relevant, fastPath: true) + "\n").utf8))
            }
            exit(diags.contains { $0.severity == .error } ? 1 : 0)
        }

        // 1. Lectura + hash + prefiltro (solo archivos con mtime/size distinto)
        let previous = cache.entries
        let prefiltered: [(ScannedFile, CacheEntry, Data?)] = await withTaskGroup(of: (ScannedFile, CacheEntry, Data?).self) { group in
            for f in files {
                group.addTask {
                    if let old = previous[f.path], old.mtime == f.mtime, old.size == f.size {
                        return (f, old, nil)
                    }
                    let data = FileManager.default.contents(atPath: f.path) ?? Data()
                    let hash = Hashing.fnv1a(data)
                    if let old = previous[f.path], old.hash == hash {
                        var e = old; e.mtime = f.mtime; e.size = f.size
                        return (f, e, nil)
                    }
                    let relevant = markers.contains { data.range(of: $0) != nil }
                    return (f, CacheEntry(mtime: f.mtime, size: f.size, hash: hash, relevant: relevant, facts: nil), relevant ? data : nil)
                }
            }
            var out: [(ScannedFile, CacheEntry, Data?)] = []
            for await r in group { out.append(r) }
            return out
        }
        clock.mark("prefilter")

        // 2. Parseo en paralelo
        let toParse = prefiltered.filter { $0.2 != nil }
        let trees: [(String, SourceFileSyntax)] = await withTaskGroup(of: (String, SourceFileSyntax).self) { group in
            for (f, _, data) in toParse {
                group.addTask {
                    let tree = data!.withUnsafeBytes { raw in
                        Parser.parse(source: UnsafeBufferPointer(start: raw.bindMemory(to: UInt8.self).baseAddress, count: raw.count))
                    }
                    return (f.path, tree)
                }
            }
            var out: [(String, SourceFileSyntax)] = []
            for await r in group { out.append(r) }
            return out
        }
        clock.mark("parse")

        // 3. Extracción en paralelo
        let extracted: [String: FileFacts] = await withTaskGroup(of: (String, FileFacts).self) { group in
            for (path, tree) in trees {
                group.addTask { (path, FactExtractor.extract(from: tree, fileName: path)) }
            }
            var out: [String: FileFacts] = [:]
            for await (p, f) in group { out[p] = f }
            return out
        }
        clock.mark("extract")

        var entries: [String: CacheEntry] = [:]
        for (f, entry, _) in prefiltered {
            var e = entry
            if let facts = extracted[f.path] { e.facts = facts }
            entries[f.path] = e
        }
        let reused = prefiltered.filter { $0.2 == nil && $0.1.relevant }.count

        // 4. Validación
        var allFacts = entries.compactMap { path, e in e.facts.map { (file: path, facts: $0) } }
            .sorted { $0.file < $1.file }
        let localFactCount = allFacts.count
        for path in manifestPaths {
            guard let data = FileManager.default.contents(atPath: path),
                  let manifest = try? JSONDecoder().decode(GraphManifest.self, from: data),
                  manifest.schema == GraphManifest.schema else {
                FileHandle.standardError.write(Data("dagger-graph: no se pudo leer el manifiesto \(path)\n".utf8))
                exit(2)
            }
            // Las raíces de otros paquetes no se re-validan aquí: solo aportan bindings y módulos.
            for (file, var facts) in manifest.files.sorted(by: { $0.key < $1.key }) {
                facts.roots = []
                allFacts.append((file: "\(manifest.name)::\(file)", facts: facts))
            }
        }
        var validator = Validator(facts: allFacts)
        validator.extraImports = Set(extraImports)
        // Los diagnósticos de archivos de manifiestos son del otro paquete: aquí solo los locales.
        let diags = validator.run().filter { !$0.file.contains("::") }
        clock.mark("validate")

        if manifestMode, let generateOut, let manifestName {
            let local = Array(allFacts.prefix(localFactCount))
            let manifest = makeManifest(name: manifestName, facts: local, roots: roots)
            if let data = try? JSONEncoder.sorted.encode(manifest) {
                try? data.write(to: URL(fileURLWithPath: generateOut))
            }
            FileHandle.standardError.write(Data("[dagger-graph manifest] \(manifestName): \(manifest.provides.count) provistos · \(manifest.requires.count) requeridos · \(manifest.scopes.count) scopes → \(generateOut)\n".utf8))
        }

        if generateMode, let generateOut, !diags.contains(where: { $0.severity == .error }) {
            let (files, skipped) = validator.generate(rootsIn: rootsIn, targetModule: targetModule)
            let written = writeGenerated(files, to: generateOut)
            clock.mark("generate")
            FileHandle.standardError.write(Data("[dagger-graph generate] \(files.count) archivos (\(written) reescritos) en \(generateOut)\n".utf8))
            for s in skipped {
                FileHandle.standardError.write(Data("  omitido: \(s)\n".utf8))
            }
        }

        emit(diags)
        if let outputSwift { writeStamp(outputSwift, diagnostics: diags, files: entries.count) }

        if useCache {
            cache.entries = entries
            cache.diagnostics = diags
            let url = URL(fileURLWithPath: cachePath)
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(cache) { try? data.write(to: url) }
            clock.mark("cache-write")
        }

        if timings {
            let relevant = entries.values.filter(\.relevant).count
            FileHandle.standardError.write(Data((clock.report(parsed: trees.count, relevant: relevant, total: files.count, reused: reused, fastPath: false) + "\n").utf8))
        }
        exit(diags.contains { $0.severity == .error } ? 1 : 0)
    }

    /// Salida del build-tool plugin: un archivo Swift sin código (solo un comentario estable) que
    /// SwiftPM/Xcode compilan con el target. Se reescribe solo si cambia, para no invalidar el build.
    static func writeStamp(_ path: String, diagnostics: [Diagnostic], files: Int) {
        let errors = diagnostics.filter { $0.severity == .error }.count
        let warnings = diagnostics.filter { $0.severity == .warning }.count
        let content = "// Generado por dagger-graph. No editar.\n// \(files) archivos · \(errors) errores · \(warnings) advertencias\n"
        if let existing = try? String(contentsOfFile: path, encoding: .utf8), existing == content { return }
        try? FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? content.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Escribe solo los archivos cuyo contenido cambió y borra generados obsoletos (`DaggerGraph_*.swift`).
    static func writeGenerated(_ files: [GeneratedFile], to dir: String) -> Int {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        var written = 0
        let names = Set(files.map(\.name))
        for f in files {
            let path = (dir as NSString).appendingPathComponent(f.name)
            if let existing = try? String(contentsOfFile: path, encoding: .utf8), existing == f.content { continue }
            try? f.content.write(toFile: path, atomically: true, encoding: .utf8)
            written += 1
        }
        for stale in (try? fm.contentsOfDirectory(atPath: dir)) ?? []
        where stale.hasPrefix("DaggerGraph_") && stale.hasSuffix(".swift") && !names.contains(stale) {
            try? fm.removeItem(atPath: (dir as NSString).appendingPathComponent(stale))
        }
        return written
    }

    static func makeManifest(name: String, facts: [(file: String, facts: FileFacts)], roots: [String]) -> GraphManifest {
        var provides = Set<String>(), required = Set<String>(), scopes = Set<String>(), modules = Set<String>()
        var files: [String: FileFacts] = [:]
        for (file, f) in facts {
            var rel = file
            // Ruta relativa prefijada con el nombre del directorio raíz (evita choques entre directorios).
            for r in roots where file.hasPrefix(r) {
                let base = URL(fileURLWithPath: r).lastPathComponent
                rel = base + "/" + String(file.dropFirst(r.count)).trimmingCharacters(in: ["/"])
            }
            files[rel] = f
            for b in f.bindings {
                provides.insert(b.provides)
                if case .scope(let s) = b.lifetime { scopes.insert(s) }
                b.deps.forEach { required.insert($0.type) }
            }
            f.modules.forEach { modules.insert($0.name) }
        }
        let validator = Validator(facts: facts)
        let unresolved = required.filter { validator.providerIndices(for: $0) == nil && !Validator.builtins.contains($0) }
        return GraphManifest(
            name: name, provides: provides.sorted(), requires: unresolved.sorted(),
            scopes: scopes.sorted(), modules: modules.sorted(), files: files
        )
    }

    static func emit(_ diags: [Diagnostic]) {
        guard !diags.isEmpty else { return }
        print(diags.map(\.rendered).joined(separator: "\n"))
    }

    static func scan(_ root: String) -> [ScannedFile] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        let base = URL(fileURLWithPath: root)
        guard let en = FileManager.default.enumerator(at: base, includingPropertiesForKeys: keys) else { return [] }
        var out: [ScannedFile] = []
        let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
        for case let url as URL in en {
            let v = try? url.resourceValues(forKeys: Set(keys))
            if v?.isDirectory == true {
                let name = url.lastPathComponent
                if name.hasPrefix(".") || skipDirs.contains(name) { en.skipDescendants() }
                continue
            }
            guard url.pathExtension == "swift" else { continue }
            let rel = url.path.hasPrefix(prefix) ? String(url.path.dropFirst(prefix.count)) : url.path
            let display = (root as NSString).appendingPathComponent(rel)
            out.append(ScannedFile(
                path: display,
                mtime: v?.contentModificationDate?.timeIntervalSince1970 ?? 0,
                size: v?.fileSize ?? 0
            ))
        }
        return out
    }
}

extension JSONEncoder {
    static var sorted: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return e
    }
}
