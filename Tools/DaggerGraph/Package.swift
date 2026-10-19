// swift-tools-version: 6.0
// Paquete SEPARADO a propósito: `dagger-graph` depende de swift-syntax y no queremos que
// los consumidores de `DaggerSwift` (cero dependencias externas) tengan que resolverlo.
// Spike de medición (Fase 1) — validación compile-time del grafo sin tocar runtime ni macros.

import PackageDescription

let package = Package(
    name: "DaggerGraph",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "dagger-graph", targets: ["DaggerGraph"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "600.0.0"..<"601.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "DaggerGraph",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            path: "Sources/DaggerGraph"
        ),
    ]
)
