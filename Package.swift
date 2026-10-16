// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "DaggerSwift",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .macCatalyst(.v17)],
    products: [
        .library(
            name: "DaggerSwift",
            targets: ["DaggerSwift"]
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

        // Biblioteca que expone el motor del grafo y las macros como parte de su API
        .target(
            name: "DaggerSwift",
            dependencies: ["DaggerSwiftMacros"],
            path: "Sources/DaggerSwift"
        ),

        // Herramienta CLI de terminal que demuestra el grafo, macros, perfil @fsaldivar-dev y auditoría de memoria
        .executableTarget(
            name: "DaggerCLI",
            dependencies: ["DaggerSwift"],
            path: "Sources/DaggerCLI"
        ),

        // Target de pruebas para validar las macros y el motor de grafo (v1 y v2)
        .testTarget(
            name: "DaggerSwiftTest",
            dependencies: ["DaggerSwift"],
            path: "Test"
        ),
    ]
)
