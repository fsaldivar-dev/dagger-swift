// swift-tools-version: 6.0
// Consumidor de humo para releases: compila @Inject/@Module contra el paquete que indique
// DAGGER_SWIFT_PATH (checkout fuente o checkout de release con XCFramework) y resuelve el grafo
// en tests. Sin ejecutable para poder correrlo también en iOS Simulator (xcodebuild test).
import PackageDescription

let daggerPath = Context.environment["DAGGER_SWIFT_PATH"] ?? "../.."

let package = Package(
    name: "ReleaseConsumer",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ReleaseConsumerGraph", targets: ["ReleaseConsumerGraph"]),
    ],
    dependencies: [
        .package(name: "DaggerSwift", path: daggerPath),
    ],
    targets: [
        .target(
            name: "ReleaseConsumerGraph",
            dependencies: [.product(name: "DaggerSwift", package: "DaggerSwift")]
        ),
        .testTarget(
            name: "ReleaseConsumerTests",
            dependencies: ["ReleaseConsumerGraph", .product(name: "DaggerSwift", package: "DaggerSwift")]
        ),
    ]
)
