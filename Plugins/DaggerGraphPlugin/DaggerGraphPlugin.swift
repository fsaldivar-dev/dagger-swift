//
//  DaggerGraphPlugin.swift
//  DaggerGraphPlugin
//
//  Command plugin: `swift package dagger-graph [--timings] [dirs...]`.
//  Solo se declara en el Package.swift de los tags de release, donde `dagger-graph` llega como
//  artifactbundle precompilado (sin compilar swift-syntax en el proyecto del consumidor).
//  En `main` la herramienta vive en Tools/DaggerGraph y se usa desde fuente.
//

import Foundation
import PackagePlugin

@main
struct DaggerGraphPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "dagger-graph")
        var args = arguments
        if !args.contains(where: { !$0.hasPrefix("--") }) {
            args.append(context.package.directoryURL.path)
        }
        if !args.contains("--cache") && !args.contains("--no-cache") {
            args += ["--cache", context.pluginWorkDirectoryURL.appendingPathComponent("dagger-graph-cache.json").path]
        }

        let process = Process()
        process.executableURL = tool.url
        process.arguments = args
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            Diagnostics.error("dagger-graph encontró errores en el grafo (exit \(process.terminationStatus))")
            throw ExitCode(process.terminationStatus)
        }
    }
}

struct ExitCode: Error, CustomStringConvertible {
    let code: Int32
    init(_ code: Int32) { self.code = code }
    var description: String { "dagger-graph terminó con código \(code)" }
}
