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
        .library(name: "SampleProyect", targets: ["SampleProyect"]),
    ],
    dependencies: [
        .package(name: "DaggerSwift", path: "../../")
    ],
    targets: [
        // 1. Foundation: Entidades compartidas, modelos de dominio y Design System
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

        // 3. Services: Implementaciones de Red (GitHub REST / Faker), Sesión, Feature Flags y @Module de entornos
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

        // 5. SampleProyect (App Root): Une las capas para los targets ejecutables Demo y DemoFaker
        .target(
            name: "SampleProyect",
            dependencies: [
                "DaggerSwift",
                "AppFoundation",
                "Core",
                "Services",
                "Features"
            ]
        ),

        .testTarget(
            name: "SampleProyectTests",
            dependencies: ["SampleProyect"]
        ),
    ]
)
