// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iMetalPlugin",
    products: [
        // Products can be used to vend plugins, making them visible to other packages.
        .plugin(
            name: "iMetalPlugin",
            targets: ["iMetalPlugin"]
        ),
        .executable(name: "CIMetalCompilerTool", targets: ["CIMetalCompilerTool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .plugin(
            name: "iMetalPlugin",
            capability: .buildTool(),
            dependencies: ["CIMetalCompilerTool"]
        ),
        .executableTarget(name: "CIMetalCompilerTool", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
    ]
)
