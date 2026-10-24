// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SampleProyect",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AppFoundation", targets: ["AppFoundation"]),
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Services", targets: ["Services"]),
        .library(name: "Features", targets: ["Features"]),
        .library(name: "MultiCountryNewsDemo", targets: ["MultiCountryNewsDemo"]),
        .library(name: "FintechMockupDemo", targets: ["FintechMockupDemo"]),
        .library(name: "SampleProyect", targets: ["SampleProyect"]),
    ],
    dependencies: [
        .package(name: "DaggerSwift", path: "../../"),
        // Validación del grafo en cada build (build-tool plugin; en main usa dagger-graph desde fuente).
        .package(name: "DaggerGraph", path: "../../Tools/DaggerGraph"),
    ],
    targets: [
        // 1. Foundation: Entidades compartidas y Design System
        .target(
            name: "AppFoundation",
            dependencies: []
        ),

        // 2. Core: Contratos (Protocols), Casos de Uso (@Inject), @Precondition y @BusinessRule
        .target(
            name: "Core",
            dependencies: [
                "DaggerSwift",
                "AppFoundation"
            ]
        ),

        // 3. Services: Implementaciones de Red (GitHub REST), Sesión, Feature Flags y @Module
        .target(
            name: "Services",
            dependencies: [
                "DaggerSwift",
                "AppFoundation",
                "Core"
            ]
        ),

        // 4. Features: Pantallas y ViewModels MVVM con @Inject (desacoplados de Services)
        .target(
            name: "Features",
            dependencies: [
                "DaggerSwift",
                "AppFoundation",
                "Core"
            ]
        ),

        // 5. Target Demo 1: Login Multi-Country + Home de Noticias en 4 Idiomas (MX, US, BR, FR)
        .target(
            name: "MultiCountryNewsDemo",
            dependencies: [
                "DaggerSwift",
                "AppFoundation"
            ]
        ),

        // 6. Target Demo 2: App Mockup Fintech con Paleta Module(0.1), Module(1.0), Module(2.0) y A/B Flags
        .target(
            name: "FintechMockupDemo",
            dependencies: [
                "DaggerSwift",
                "AppFoundation"
            ]
        ),

        // 7. SampleProyect (App Root): Selector con botones para lanzar cualquiera de las Demo Apps
        .target(
            name: "SampleProyect",
            dependencies: [
                "DaggerSwift",
                "AppFoundation",
                "Core",
                "Services",
                "Features",
                "MultiCountryNewsDemo",
                "FintechMockupDemo"
            ],
            plugins: [.plugin(name: "DaggerGraphBuildPlugin", package: "DaggerGraph")]
        ),

        // Target de Test 1: Pruebas Unitarias de la App (UseCases y ViewModels)
        .testTarget(
            name: "AppUnitTests",
            dependencies: ["SampleProyect"]
        ),

        // Target de Test 2: Pruebas del Grafo de Dependencias
        .testTarget(
            name: "AppGraphTests",
            dependencies: [
                "SampleProyect",
                .product(name: "DaggerSwiftTesting", package: "DaggerSwift")
            ]
        ),
    ]
)
