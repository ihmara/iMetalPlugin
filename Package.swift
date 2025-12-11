// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpryMetalPlugin",
    products: [
        // Expose the build tool plugin so other packages can use it
        .plugin(
            name: "SpryMetalPlugin",
            targets: ["SpryMetalPlugin"]
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
            name: "SpryMetalPlugin",
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
