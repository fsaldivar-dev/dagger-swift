//
//  DaggerGraphBuildPlugin.swift
//  DaggerGraphBuildPlugin
//
//  Build-tool plugin: valida el grafo de DaggerSwift en cada build del target al que se aplica.
//  Entradas: los .swift del target y de sus dependencias locales (mismo paquete / proyecto).
//  Salida: un .swift sin código que el target compila; dagger-graph solo lo reescribe si cambió,
//  así que un build sin cambios no recompila nada. Errores del grafo = build fallido, con
//  diagnósticos `archivo:línea:col: error:` que SwiftPM y Xcode muestran en el código.
//
//  En `main` usa la herramienta desde fuente (Tools/DaggerGraph); en los tags de release la
//  misma fuente se declara contra el artifactbundle precompilado.
//

import Foundation
import PackagePlugin

@main
struct DaggerGraphBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let module = target as? SourceModuleTarget else { return [] }
        let root = context.package.directoryURL.standardizedFileURL.path
        var modules: [SourceModuleTarget] = [module]
        for dependency in module.recursiveTargetDependencies {
            // Solo código del paquete propio: DaggerSwift y otras dependencias externas no aportan grafo.
            if let source = dependency as? SourceModuleTarget,
               let dir = Self.commonDirectory(source), dir.standardizedFileURL.path.hasPrefix(root) {
                modules.append(source)
            }
        }
        return try [
            makeCommand(
                tool: try Self.tool(context.tool(named:)),
                directories: modules.compactMap(Self.commonDirectory),
                inputs: modules.flatMap { $0.sourceFiles(withSuffix: "swift").map(\.url) },
                workDirectory: context.pluginWorkDirectoryURL,
                displayName: "dagger-graph \(target.name)"
            ),
        ]
    }

    /// Directorio común de los archivos del módulo (en PackagePlugin 6.0 `directoryURL` no está disponible
    /// sobre `SourceModuleTarget`).
    static func commonDirectory(_ module: SourceModuleTarget) -> URL? {
        let dirs = module.sourceFiles(withSuffix: "swift").map { $0.url.deletingLastPathComponent().standardizedFileURL.pathComponents }
        guard var common = dirs.first else { return nil }
        for d in dirs.dropFirst() {
            common = Array(zip(common, d).prefix { $0 == $1 }.map(\.0))
        }
        return URL(fileURLWithPath: common.joined(separator: "/").replacingOccurrences(of: "//", with: "/"))
    }

    /// `dagger-graph` cuando llega como artifactbundle (release); `DaggerGraph` cuando es el target fuente.
    static func tool(_ lookup: (String) throws -> PluginContext.Tool) throws -> URL {
        if let binary = try? lookup("dagger-graph") { return binary.url }
        return try lookup("DaggerGraph").url
    }

    func makeCommand(
        tool: URL,
        directories: [URL],
        inputs: [URL],
        workDirectory: URL,
        displayName: String
    ) throws -> Command {
        let output = workDirectory.appendingPathComponent("DaggerGraphValidated.swift")
        return .buildCommand(
            displayName: displayName,
            executable: tool,
            arguments: [
                "--cache", workDirectory.appendingPathComponent("dagger-graph-cache.json").path,
                "--output-swift", output.path,
            ] + directories.map(\.path),
            inputFiles: inputs,
            outputFiles: [output]
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension DaggerGraphBuildPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        let swiftFiles = target.inputFiles.filter { $0.url.pathExtension == "swift" }.map(\.url)
        let directories = Array(Set(swiftFiles.map { $0.deletingLastPathComponent() }))
            .sorted { $0.path < $1.path }
        return [
            try makeCommand(
                tool: try Self.tool(context.tool(named:)),
                directories: directories,
                inputs: swiftFiles,
                workDirectory: context.pluginWorkDirectoryURL,
                displayName: "dagger-graph \(target.displayName)"
            ),
        ]
    }
}
#endif
