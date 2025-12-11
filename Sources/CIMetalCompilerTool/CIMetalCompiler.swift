import ArgumentParser
import Foundation
import os

#if os(macOS)
/// Useful links:
/// - Clang modules caveats: https://clang.llvm.org/docs/Modules.html#problems-with-the-current-model
/// - xcrun man page:      https://keith.github.io/xcode-man-pages/xcrun.1.html
/// - Precompiling Metal:  https://developer.apple.com/documentation/metal/building-a-shader-library-by-precompiling-source-files
@main
@available(macOS 13.0, *)
struct CIMetalCompilerTool: ParsableCommand {
    @Option(name: .long, help: "Path to the final merged .metallib output.")
    var output: String
    
    @Option(name: .long, help: "Directory for intermediate .air and .metallib files.")
    var cache: String
    
    @Argument(help: "List of input .metal source files.")
    var inputs: [String]
    
    mutating func run() throws {
        print("=== [CIMetalCompilerTool] Starting compilation ===")
        print("Output: \(output)")
        print("Cache directory: \(cache)")
        print("Inputs: \(inputs.joined(separator: ", "))")
        
        let xcRunURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        
        // Ensure cache directory exists
        try FileManager.default.createDirectory(atPath: cache, withIntermediateDirectories: true)
        
        var airOutputs = [String]()
        
        // STEP 1: Compile each .metal source file into an .air intermediate.
        print("\n--- Step 1: Compiling .metal files to .air ---")
        for input in inputs {
            let name = input.nameWithoutExtension
            let airOutput = "\(cache)/\(name).air"
            
            let p = Process()
            p.executableURL = xcRunURL
            p.arguments = [
                "metal",
                "-c",
                "-fcikernel",
                input,
                "-o",
                airOutput,
                "-fmodules=none" // Disable modules to avoid issues in CI environments.
            ]
            
            try p.run()
            p.waitUntilExit()
            let status = p.terminationStatus
            
            if status != 0 {
                throw CompileError(message: """
                [ERROR] Failed to compile .metal file:
                Input: \(input)
                Output: \(airOutput)
                Exit code: \(status)
                """)
            } else {
                print("[OK] Compiled \(input) → \(airOutput)")
            }
            
            airOutputs.append(airOutput)
        }
        
        var metalLibs = [String]()
        
        // STEP 2: Link each .air file into its own .metallib.
        print("\n--- Step 2: Linking .air files to individual .metallib ---")
        for airFile in airOutputs {
            let name = airFile.nameWithoutExtension
            let metalLibOutput = "\(cache)/\(name).metallib"
            
            print("Linking \(airFile) → \(metalLibOutput)")
            
            let p = Process()
            p.executableURL = xcRunURL
            p.arguments = [
                "metallib",
                "--cikernel",
                airFile,
                "-o",
                metalLibOutput
            ]
            
            try p.run()
            p.waitUntilExit()
            let status = p.terminationStatus
            
            if status != 0 {
                throw CompileError(message: """
                [ERROR] Failed to link .air file:
                Input: \(airFile)
                Output: \(metalLibOutput)
                Exit code: \(status)
                """)
            } else {
                print("[OK] Linked \(airFile) → \(metalLibOutput)")
            }
            
            metalLibs.append(metalLibOutput)
        }
        
        // STEP 3: Merge all .air files into the final output .metallib.
        print("\n--- Step 3: Merging all AIR files into final metallib ---")
        print("Merging \(airOutputs.count) AIR files → \(output)")
        
        let p = Process()
        p.executableURL = xcRunURL
        p.arguments = [
            "metal",
            "-fcikernel",
            "-o",
            output,
        ] + airOutputs
        
        try p.run()
        p.waitUntilExit()
        let status = p.terminationStatus
        
        if status != 0 {
            throw CompileError(message: """
            [ERROR] Failed to merge AIR files into final metallib:
            Output: \(output)
            Exit code: \(status)
            """)
        } else {
            print("\n==== [CIMetalCompilerTool] Completed successfully ====")
            print("Final metallib: \(output)")
        }
    }
}
#else
@main
struct CIMetalCompilerTool: ParsableCommand {
    @Option(name: .long)
    var output: String
    
    @Option(name: .long)
    var cache: String
    
    @Argument
    var inputs: [String]
    
    mutating func run() throws {
        throw CompileError(message: "[ERROR] CIMetalCompilerTool is not supported on macOS Catalyst.")
    }
}
#endif

extension String {
    var nameWithoutExtension: String {
        guard let url = URL(string: self) else {
            fatalError("Invalid URL string: \(self)")
        }
        return url.deletingPathExtension().lastPathComponent
    }
}

struct CompileError: Error {
    let message: String
}

