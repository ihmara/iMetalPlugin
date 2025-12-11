// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "iMetalPlugin",
    products: [
        // Expose the build tool plugin so other packages can use it
        .plugin(
            name: "iMetalPlugin",
            targets: ["iMetalPlugin"]
        ),
        // Expose the executable tool (used by the plugin)
        .executable(
            name: "CIMetalCompilerTool",
            targets: ["CIMetalCompilerTool"]
        ),
    ],
    dependencies: [
        // ArgumentParser for command-line parsing in the executable
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        // Build tool plugin target
        .plugin(
            name: "iMetalPlugin",
            capability: .buildTool(),
            dependencies: [
                "CIMetalCompilerTool" // The executable tool used by the plugin
            ]
        ),
        // Executable target for the Metal compiler tool
        .executableTarget(
            name: "CIMetalCompilerTool",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
    ]
)
