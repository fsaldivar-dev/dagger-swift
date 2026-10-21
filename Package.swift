// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "DaggerSwift",
    // Mínimos reales del runtime (parameter packs en funciones se pueden usar desde iOS 13; nada requiere iOS 17).
    // Bajarlos desbloquea apps que soportan iOS 15/16 (p. ej. Firefox for iOS).
    platforms: [.macOS(.v12), .iOS(.v15), .tvOS(.v15), .watchOS(.v8), .visionOS(.v1), .macCatalyst(.v15)],
    products: [
        .library(
            name: "DaggerSwift",
            targets: ["DaggerSwift"]
        ),
        .library(
            name: "DaggerSwiftTesting",
            targets: ["DaggerSwiftTesting"]
        ),
        .executable(
            name: "dagger-cli",
            targets: ["DaggerCLI"]
        ),
    ],
    targets: [
        // Compiler Plugin nativo (Swift Macros: @Module, @Inject, @Singleton, @Scoped, @Provider, @BusinessRule, @Precondition)
        .macro(
            name: "DaggerSwiftMacros",
            dependencies: [],
            path: "Sources/DaggerSwiftMacros"
        ),

        // Runtime puro (motor del grafo, scopes, SwiftUI). En los tags de release este target
        // se sustituye por un `.binaryTarget` (XCFramework) — ver scripts/release-dry-run.sh.
        .target(
            name: "DaggerSwiftCore",
            dependencies: [],
            path: "Sources/DaggerSwiftCore"
        ),

        // Target fuente delgado: declaraciones de macros + `@_exported import DaggerSwiftCore`.
        // Las macros no pueden ser binarias en SwiftPM, así que esto siempre compila desde fuente.
        .target(
            name: "DaggerSwift",
            dependencies: ["DaggerSwiftCore", "DaggerSwiftMacros"],
            path: "Sources/DaggerSwift"
        ),

        // Sub-target oficial de Testing (Tags de Swift Testing, Snapshots JSON, Diagramas y Comparativas de Fallo)
        .target(
            name: "DaggerSwiftTesting",
            dependencies: ["DaggerSwift"],
            path: "Sources/DaggerSwiftTesting"
        ),

        // Herramienta CLI de terminal que demuestra el grafo, macros, perfil @fsaldivar-dev y auditoría de memoria
        .executableTarget(
            name: "DaggerCLI",
            dependencies: ["DaggerSwift"],
            path: "Sources/DaggerCLI"
        ),

        // Tests de expansión de las macros: llaman al plugin con mensajes del protocolo (sin swift-syntax).
        .testTarget(
            name: "DaggerSwiftMacrosTests",
            dependencies: ["DaggerSwiftMacros"],
            path: "MacroTests"
        ),

        // Target de pruebas para validar las macros y el motor de grafo (v1 y v2)
        .testTarget(
            name: "DaggerSwiftTest",
            dependencies: ["DaggerSwift", "DaggerSwiftTesting"],
            path: "Test"
        ),
    ]
)
