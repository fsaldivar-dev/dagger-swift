// swift-tools-version: 6.0
// Consumidor de humo para releases: compila @Inject/@Module contra el paquete que indique
// DAGGER_SWIFT_PATH (checkout fuente o checkout de release con XCFramework) y ejecuta el grafo.
import PackageDescription

let daggerPath = Context.environment["DAGGER_SWIFT_PATH"] ?? "../.."

let package = Package(
    name: "ReleaseConsumer",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "DaggerSwift", path: daggerPath),
    ],
    targets: [
        .executableTarget(
            name: "ReleaseConsumer",
            dependencies: [.product(name: "DaggerSwift", package: "DaggerSwift")]
        ),
    ]
)
