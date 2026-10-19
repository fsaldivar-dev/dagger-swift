#!/usr/bin/env python3
"""Genera el Package.swift de un tag de release a partir del de `main`.

- `DaggerSwiftCore` pasa de `.target` (fuente) a `.binaryTarget` (XCFramework) en plataformas Apple;
  en Linux se queda en fuente (#if os(Linux)).
- Agrega `dagger-graph` como `.binaryTarget` (artifactbundle) + command plugin `dagger-graph`.
- `DaggerSwift` (declaraciones de macros) y `DaggerSwiftMacros` siguen en fuente: SwiftPM no admite macros binarias.

Uso:
  make-release-manifest.py --in Package.swift --out Package.swift \
      (--core-url URL --core-checksum SHA | --core-path RUTA) \
      (--graph-url URL --graph-checksum SHA | --graph-path RUTA)
"""
import argparse
import re
import sys


def binary(name, url, checksum, path, indent=""):
    if path:
        return f'.binaryTarget(name: "{name}", path: "{path}")'
    i = indent
    return f'.binaryTarget(\n{i}    name: "{name}",\n{i}    url: "{url}",\n{i}    checksum: "{checksum}"\n{i})'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--out", dest="dst", required=True)
    ap.add_argument("--core-url"); ap.add_argument("--core-checksum"); ap.add_argument("--core-path")
    ap.add_argument("--graph-url"); ap.add_argument("--graph-checksum"); ap.add_argument("--graph-path")
    a = ap.parse_args()
    if not (a.core_path or (a.core_url and a.core_checksum)):
        sys.exit("falta --core-path o --core-url + --core-checksum")
    if not (a.graph_path or (a.graph_url and a.graph_checksum)):
        sys.exit("falta --graph-path o --graph-url + --graph-checksum")

    s = open(a.src).read()

    core_src = re.search(r'\.target\(\s*name: "DaggerSwiftCore".*?\n        \),', s, re.S)
    if not core_src:
        sys.exit("no se encontró el target DaggerSwiftCore en el manifiesto")
    s = s.replace(core_src.group(0), "coreTarget,", 1)

    s = s.rstrip() + "\n"

    preamble = f'''
// ── Manifiesto de RELEASE (generado por scripts/make-release-manifest.py) ──
// El runtime llega precompilado (XCFramework); las macros siguen en fuente porque SwiftPM
// no admite macros binarias. En `main` todo es fuente.
#if os(Linux)
let coreTarget: Target = .target(name: "DaggerSwiftCore", dependencies: [], path: "Sources/DaggerSwiftCore")
let graphProducts: [Product] = []
let graphTargets: [Target] = []
#else
let coreTarget: Target = {binary("DaggerSwiftCore", a.core_url, a.core_checksum, a.core_path)}
let graphProducts: [Product] = [
    .plugin(name: "DaggerGraphPlugin", targets: ["DaggerGraphPlugin"]),
    .plugin(name: "DaggerGraphBuildPlugin", targets: ["DaggerGraphBuildPlugin"]),
]
let graphTargets: [Target] = [
    {binary("dagger-graph", a.graph_url, a.graph_checksum, a.graph_path, indent="    ")},
    .plugin(
        name: "DaggerGraphPlugin",
        capability: .command(
            intent: .custom(verb: "dagger-graph", description: "Valida el grafo de DaggerSwift (bindings, ciclos, scopes)")
        ),
        dependencies: ["dagger-graph"],
        path: "Plugins/DaggerGraphPlugin"
    ),
    // Misma fuente que en Tools/DaggerGraph, pero contra el binario: valida en cada build sin swift-syntax.
    .plugin(
        name: "DaggerGraphBuildPlugin",
        capability: .buildTool(),
        dependencies: ["dagger-graph"],
        path: "Tools/DaggerGraph/Plugins/DaggerGraphBuildPlugin"
    ),
]
#endif
'''
    # Insertar después de los imports.
    idx = s.rfind("import CompilerPluginSupport")
    if idx < 0:
        sys.exit("no se encontró 'import CompilerPluginSupport'")
    eol = s.index("\n", idx) + 1
    s = s[:eol] + preamble + s[eol:]

    # Concatenar productos/targets condicionales al final de los arrays del Package(...).
    m = re.search(r'(\n    \],\n    targets: \[)', s)
    s = s[:m.start()] + "\n    ] + graphProducts,\n    targets: [" + s[m.end():]
    last = s.rfind("\n    ]\n)")
    if last < 0:
        sys.exit("no se encontró el cierre de targets")
    s = s[:last] + "\n    ] + graphTargets\n)" + s[last + len("\n    ]\n)"):]

    open(a.dst, "w").write(s)


if __name__ == "__main__":
    main()
