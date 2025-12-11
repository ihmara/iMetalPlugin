import Foundation
import os
import PackagePlugin

@main
struct CIMetalPlugin: BuildToolPlugin {
    func createBuildCommands(context: PackagePlugin.PluginContext, target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
        // Collect all .metal files under the target directory (recursively).
        var metalURLs: [URL] = []
        walkDirectory(target.directoryURL) { url in
            if url.pathExtension == "metal" {
                metalURLs.append(url)
            }
        }

        // Deduplicate and sort (optional: stable order by path).
        let uniqueMetalURLs = Array(Set(metalURLs)).sorted { $0.path < $1.path }

        let cacheURL = context.pluginWorkDirectoryURL.appending(path: "cache", directoryHint: .isDirectory)
        let outputURL = context.pluginWorkDirectoryURL.appending(path: "ThresholdPaintAlphaFilterKernel.ci.metallib")

        guard !uniqueMetalURLs.isEmpty else {
            Diagnostics.remark("[CIMetalPlugin] No .metal files found in \(target.directoryURL.path). Skipping CIMetalCompilerTool.")
            return []
        }

        // Emit a concise list of discovered shader files (filenames only).
        let names = uniqueMetalURLs.map { $0.lastPathComponent }.joined(separator: ", ")
        Diagnostics.remark("[CIMetalPlugin] Found \(uniqueMetalURLs.count) .metal file(s): \(names)")

        return [
            .buildCommand(
                displayName: "Compile CI Metal Shaders (\(uniqueMetalURLs.count) file(s))",
                executable: try context.tool(named: "CIMetalCompilerTool").url,
                arguments: [
                    "--output", outputURL.path(),
                    "--cache", cacheURL.path(),
                ] + uniqueMetalURLs.map { $0.path },
                environment: [:],
                inputFiles: uniqueMetalURLs,
                outputFiles: [outputURL]
            )
        ]
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
            Diagnostics.warning("[CIMetalPlugin] Failed to enumerate \(url.path): \(error.localizedDescription)")
            return true // continue
        }
    )

    guard let e = enumerator else {
        Diagnostics.error("[CIMetalPlugin] Could not create enumerator for \(root.path)")
        return
    }

    for case let url as URL in e {
        visitor(url)
    }
}
