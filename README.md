
# CIMetalPlugin

A Swift Package **build tool plugin** and companion executable that precompiles **Core Image Metal kernels** (`*.ci.metal`) into `.metallib` files during your package build. It walks your target directory, compiles each `.metal` to `.air`, links to per-file `.metallib`, and finally merges all **AIR** files into a single output metallib when requested.

This repository contains:
- **`CIMetalPlugin`** — a SwiftPM Build Tool Plugin that discovers `.metal` sources and invokes the compiler tool.
- **`CIMetalCompilerTool`** — an executable that wraps `xcrun metal` and `xcrun metallib` for CI kernels.

> ⚠️ The executable is **macOS-only**. It won’t run on macCatalyst/iOS simulators directly; it’s invoked at build time on macOS.

---

## Features
- ✅ Recursively discovers `.metal` files in a target.
- ✅ Compiles each `.metal` → `.air` with `xcrun metal -c -fcikernel`.
- ✅ Links each `.air` → per-file `.metallib` (useful for debugging or separate distribution).
- ✅ Merges **AIR inputs** into a final **CI metallib** (e.g., `default.ci.metallib` or a custom name).
- ✅ Clear build diagnostics in Xcode/SwiftPM logs.
- ✅ Configurable: build specific “special” kernels into their own metallibs.

---

## Requirements
- **Swift Tools**: Swift 6 (package specifies `// swift-tools-version: 6.2`).
- **Platforms**: macOS 13 or later (for plugin/tool execution).
- **Xcode**: 15+ recommended.

---

## Package Layout (excerpt)

```swift
// Package.swift (plugin package)
let package = Package(
    name: "iMetalPlugin",
    platforms: [ .macOS(.v13) ],
    products: [
        .plugin(name: "iMetalPlugin", targets: ["iMetalPlugin"]),
        .executable(name: "CIMetalCompilerTool", targets: ["CIMetalCompilerTool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        .plugin(name: "iMetalPlugin", capability: .buildTool(), dependencies: ["CIMetalCompilerTool"]),
        .executableTarget(name: "CIMetalCompilerTool", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser")
        ]),
    ]
)
```

---

## How the Plugin Works
1. **Discovery**: Recursively walks `target.directoryURL`, collecting all files with extension `metal`.
2. **Special kernels**: Optional mapping that compiles certain files (e.g., `SpryColorKernels.ci.metal`, `SpryBlendKernels.ci.metal`) into their **own** metallibs.
3. **Default batch**: Remaining `.metal` files are compiled and merged into a single metallib (e.g., `default.ci.metallib`).
4. **Outputs**: All outputs are written under `context.pluginWorkDirectoryURL` to avoid touching source directories.

### Diagnostics
The plugin prints concise build logs:
- Found files: counts and filenames
- Per-step actions: compile/link/merge
- Warnings on enumeration errors

---

## Compiler Tool (`CIMetalCompilerTool`)

### Command-line interface
```
CIMetalCompilerTool --output <output.metallib> --cache <cache_dir> <input1.metal> [<input2.metal> ...]
```

### Build steps
- **Compile**: `xcrun metal -c -fcikernel <input.metal> -o <cache>/<name>.air -fmodules=none`
- **Link**: `xcrun metallib --cikernel <cache>/<name>.air> -o <cache>/<name>.metallib`
- **Merge (CI kernels)**: `xcrun metal -fcikernel -o <output.metallib> <cache>/*.air`

> ℹ️ For **Core Image kernels**, merging should consume **AIR files**, not prebuilt metallibs.

---

## Using the Plugin in Your Package

1. Add this plugin as a dependency in your consumer package:

```swift
// In your app/library Package.swift
.dependencies: [
    .package(url: "https://github.com/your-org/iMetalPlugin.git", from: "1.0.0")
],
.targets: [
    .target(
        name: "Filters",
        plugins: [ .plugin(name: "iMetalPlugin", package: "iMetalPlugin") ]
    )
]
```

2. Place your `*.ci.metal` files within the `Sources/<TargetName>/...` tree (or wherever your target files live).

3. Build — the plugin will emit `.metallib` files in the work directory and add them as build outputs.

---

## Loading the Metallib at Runtime

If you bundle the metallib as a SwiftPM resource, access it via `Bundle.module`:

```swift
import Metal

public func makeLibrary(device: MTLDevice) throws -> MTLLibrary {
    guard let url = Bundle.module.url(forResource: "default", withExtension: "ci.metallib") else {
        throw NSError(domain: "CIMetalPlugin", code: 1, userInfo: [NSLocalizedDescriptionKey: "ci.metallib not found in bundle"])
    }
    return try device.makeLibrary(URL: url)
}
```

If the metallib is embedded as a nested bundle inside your app (e.g., `Filters_Filters.bundle`), open that bundle and load the metallib:

```swift
let bundleURL = Bundle.main.url(forResource: "Filters_Filters", withExtension: "bundle")!
let filtersBundle = Bundle(url: bundleURL)!
let libURL = filtersBundle.url(forResource: "ThresholdPaintAlphaFilterKernel", withExtension: "ci.metallib")!
let library = try device.makeLibrary(URL: libURL)
```

---

## Troubleshooting

### "Multiple commands produce '.../default.metallib'"
- Ensure you **don’t** also copy a prebuilt `.metallib` into your target’s resources while **also** compiling `.metal` sources.
- If multiple targets produce metallibs into the **same bundle**, set unique names via build settings (e.g., `METAL_LIBRARY_FILE_NAME`) and load the correct file.
- In SwiftPM, let **either** the plugin **or** the native Xcode build compile your shaders — not both.

### Catalyst / iOS Simulator
- The tool runs on macOS during build. It’s **not** a runtime dependency for iOS/Catalyst.

### Empty discovery
- If the plugin reports no `.metal` files, verify their location and extension; the walker searches recursively from the target’s directory.

---

## Acknowledgements
- Built with SwiftPM Build Tool Plugins and `swift-argument-parser`.

