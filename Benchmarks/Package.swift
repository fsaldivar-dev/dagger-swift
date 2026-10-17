// swift-tools-version: 6.0
// Paquete SPM dedicado exclusivamente a Benchmarks y Debate Arquitectónico Empírico:
// Enfrenta cara a cara a DaggerSwift contra las librerías reales del ecosistema Swift:
// 1. Point-Free `swift-dependencies` (TCA / The Composable Architecture)
// 2. Michael Long `Factory` (@Injected / Container)
// 3. `Swinject` (Dynamic Dictionary Container)
// 4. `DaggerSwift` (Modo Explícito Compile-Time & Modo Motor DAG con Scopes/Preconditions)

import PackageDescription

let package = Package(
    name: "DaggerSwiftBenchmarks",
    platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [
        // Nuestro motor DaggerSwift local
        .package(path: ".."),
        // Point-Free: swift-dependencies (Usado en TCA / The Composable Architecture)
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.0"),
        // Factory: Contenedor híbrido y @Injected property wrappers
        .package(url: "https://github.com/hmlongco/Factory", from: "2.3.0"),
        // Swinject: El contenedor de registro dinámico clásico de Swift
        .package(url: "https://github.com/Swinject/Swinject", from: "2.9.1"),
    ],
    targets: [
        .testTarget(
            name: "DIFrameworksDebateTests",
            dependencies: [
                .product(name: "DaggerSwift", package: "SwiftDager"),
                .product(name: "DaggerSwiftTesting", package: "SwiftDager"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Factory", package: "Factory"),
                .product(name: "Swinject", package: "Swinject"),
            ],
            path: "Tests/DIFrameworksDebateTests"
        )
    ]
)
