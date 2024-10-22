// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "DaggerSwift",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "DaggerSwift",
            targets: ["DaggerSwift"]
        ),
    ],
    
    targets: [
        // Biblioteca que expone macros como parte de su API
        .target(
            name: "DaggerSwift",
            dependencies: [],
            path: "Sources/DaggerSwift"
        ),
        
        // Target de pruebas para desarrollar la implementación de las macros
        .testTarget(
            name: "DaggerSwiftTest",
            dependencies: ["DaggerSwift"],
            path: "Test"
        ),
    ]
)

