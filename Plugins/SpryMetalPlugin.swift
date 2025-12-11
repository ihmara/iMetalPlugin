import Foundation
import os
import PackagePlugin

@main
struct SpryMetalPlugin: BuildToolPlugin {
    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        // Collect all .metal files under the target directory (recursively).
        var metalURLs: [URL] = []
        walkDirectory(target.directoryURL) { url in
            if url.pathExtension == "metal" {
                metalURLs.append(url)
            }
        }

        // Deduplicate and sort (stable and deterministic).
        let uniqueMetalURLs = Array(Set(metalURLs)).sorted { $0.path < $1.path }

        guard !uniqueMetalURLs.isEmpty else {
            Diagnostics.remark("[SpryMetalPlugin] No .metal files found in \(target.directoryURL.path). Skipping CIMetalCompilerTool.")
            return []
        }

        // Emit a concise list of discovered shader files (filenames only).
        let names = uniqueMetalURLs.map { $0.lastPathComponent }.joined(separator: ", ")
        Diagnostics.remark("[SpryMetalPlugin] Found \(uniqueMetalURLs.count) .metal file(s): \(names)")

        var commands: [PackagePlugin.Command] = []

        // Known single-file CI kernels to compile into their own metallibs.
        let specialKernels: [(filename: String, cacheName: String, outputName: String, displayName: String)] = [
            ("SpryColorKernels.ci.metal", "SpryColorKernelsCache", "SpryColorKernels.ci.metallib", "Compile SpryColorKernels"),
            ("SpryBlendKernels.ci.metal", "SpryBlendKernelsCache", "SpryBlendKernels.ci.metallib", "Compile SpryBlendKernels")
        ]

        // Helper to build a command for a single .metal file in the special set.
        func commandForSingleKernel(
            named filename: String,
            in urls: [URL],
            context: PackagePlugin.PluginContext
        ) throws -> PackagePlugin.Command? {
            guard let url = urls.first(where: { $0.lastPathComponent == filename }) else {
                return nil
            }

            guard let matching = specialKernels.first(where: { $0.filename == filename }) else {
                Diagnostics.warning("[SpryMetalPlugin] Internal: no matching special kernel metadata for \(filename)")
                return nil
            }

            let cacheURL  = context.pluginWorkDirectoryURL.appending(path: matching.cacheName, directoryHint: .isDirectory)
            let outputURL = context.pluginWorkDirectoryURL.appending(path: matching.outputName)

            Diagnostics.remark("[SpryMetalPlugin] \(matching.displayName): \(url.lastPathComponent)")

            return .buildCommand(
                displayName: "\(matching.displayName)",
                executable: try context.tool(named: "CIMetalCompilerTool").url,
                arguments: [
                    "--output", outputURL.path(),
                    "--cache", cacheURL.path(),
                    url.path
                ],
                environment: [:],
                inputFiles: [url],
                outputFiles: [outputURL]
            )
        }

        // Build commands for the special single-file kernels.
        for kernel in specialKernels {
            if let cmd = try commandForSingleKernel(named: kernel.filename, in: uniqueMetalURLs, context: context) {
                commands.append(cmd)
            }
        }

        // Compute the remainder (all .metal files that are not special).
        let specialNames = Set(specialKernels.map { $0.filename })
        let remainingURLs = uniqueMetalURLs
            .filter { !specialNames.contains($0.lastPathComponent) }
            .sorted { $0.path < $1.path } // deterministic order

        if !remainingURLs.isEmpty {
            let cacheURL  = context.pluginWorkDirectoryURL.appending(path: "cache", directoryHint: .isDirectory)
            let outputURL = context.pluginWorkDirectoryURL.appending(path: "default.ci.metallib")

            Diagnostics.remark("[SpryMetalPlugin] Compile Default CI Kernels: \(remainingURLs.count) file(s)")

            commands.append(
                .buildCommand(
                    displayName: "Compile Default CI Kernels (\(remainingURLs.count) file(s))",
                    executable: try context.tool(named: "CIMetalCompilerTool").url,
                    arguments: [
                        "--output", outputURL.path(),
                        "--cache", cacheURL.path()
                    ] + remainingURLs.map { $0.path },
                    environment: [:],
                    inputFiles: remainingURLs,
                    outputFiles: [outputURL]
                )
            )
        } else {
            Diagnostics.remark("[SpryMetalPlugin] No remaining CI kernels to batch compile.")
        }

        return commands
    }
}

/// Recursively walks a directory URL and calls `visitor` for each discovered URL.
private func walkDirectory(_ root: URL, visitor: (URL) -> Void) {
    let fm = FileManager.default
    let options: FileManager.DirectoryEnumerationOptions = [
        .skipsHiddenFiles // ignore dotfiles and hidden folders
    ]

    let enumerator = fm.enumerator(
        at: root,
        includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
        options: options,
        errorHandler: { url, error in
            Diagnostics.warning("[SpryMetalPlugin] Failed to enumerate \(url.path): \(error.localizedDescription)")
            return true // continue
        }
    )

    guard let e = enumerator else {
        Diagnostics.error("[SpryMetalPlugin] Could not create enumerator for \(root.path)")
        return
    }

    for case let url as URL in e {
        visitor(url)
    }
}
