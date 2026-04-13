import PackagePlugin
import Foundation

@main
struct CreateBundlePlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        // Parse arguments
        var args = arguments
        var productName: String?
        var configuration = "release"

        while !args.isEmpty {
            let arg = args.removeFirst()
            switch arg {
            case "--product":
                guard !args.isEmpty else {
                    throw CreateBundleError.missingArgument("--product requires a value")
                }
                productName = args.removeFirst()
            case "--configuration", "-c":
                guard !args.isEmpty else {
                    throw CreateBundleError.missingArgument("--configuration requires a value")
                }
                configuration = args.removeFirst()
            case "--help":
                printUsage()
                return
            default:
                // Treat bare argument as product name if not set
                if productName == nil {
                    productName = arg
                }
            }
        }

        guard let product = productName else {
            printUsage()
            throw CreateBundleError.missingArgument("No product specified")
        }

        // Verify the product exists and is executable
        let allProducts = context.package.products
        guard let matched = allProducts.first(where: { $0.name == product }) else {
            let available = allProducts.map { $0.name }.joined(separator: ", ")
            throw CreateBundleError.unknownProduct(
                "'\(product)' is not a known product. Available: \(available)"
            )
        }

        // Check that the product contains at least one executable target
        let hasExecutableTarget = matched.targets.contains { target in
            (target as? SourceModuleTarget)?.kind == .executable
        }
        if !hasExecutableTarget {
            throw CreateBundleError.notExecutable(
                "'\(product)' is not an executable product. Only executables can be bundled."
            )
        }

        // Build the product
        print("Building \(product) (\(configuration))...")
        let buildResult = try packageManager.build(
            .product(product),
            parameters: .init(configuration: configuration == "debug" ? .debug : .release)
        )

        guard buildResult.succeeded else {
            throw CreateBundleError.buildFailed("Build failed for \(product)")
        }

        // Find the built executable — match by product name or product.exe (Windows).
        // Use URL-based filename extraction because SPM Path.lastComponent may not
        // handle Windows backslash separators correctly on all platforms.
        guard let artifact = buildResult.builtArtifacts.first(where: {
            guard $0.kind == .executable else { return false }
            let name = URL(fileURLWithPath: $0.path.string).lastPathComponent
            return name == product || name == "\(product).exe"
        }) else {
            throw CreateBundleError.buildFailed("Could not find built executable for \(product)")
        }

        let executablePath = artifact.path
        let executableFilename = URL(fileURLWithPath: artifact.path.string).lastPathComponent

        // Create bundle structure
        let packageDir = URL(fileURLWithPath: context.package.directory.string)
        let outputDir = packageDir.appendingPathComponent(".build/bundles")
        let bundleDir = outputDir.appendingPathComponent("\(product).app")

        let fm = FileManager.default

        // Clean previous bundle
        if fm.fileExists(atPath: bundleDir.path) {
            try fm.removeItem(at: bundleDir)
        }

        #if os(macOS)
        try createMacOSBundle(
            bundleDir: bundleDir, product: product,
            executablePath: executablePath, fm: fm
        )
        #elseif os(Windows)
        try createWindowsBundle(
            bundleDir: bundleDir, product: product,
            executablePath: executablePath,
            executableFilename: executableFilename, fm: fm
        )
        #else
        try createLinuxBundle(
            bundleDir: bundleDir, product: product,
            executablePath: executablePath, fm: fm
        )
        #endif

        // Copy Resources/ contents if the directory exists at package root.
        // The destination Resources/ directory is already created by the
        // platform-specific helpers, so we copy contents into it rather
        // than copying the directory itself (which would fail).
        let packageResources = packageDir.appendingPathComponent("Resources")
        if fm.fileExists(atPath: packageResources.path) {
            #if os(macOS)
            let destResources = bundleDir.appendingPathComponent("Contents/Resources")
            #else
            let destResources = bundleDir.appendingPathComponent("Resources")
            #endif
            let contents = try fm.contentsOfDirectory(atPath: packageResources.path)
            for item in contents {
                let src = packageResources.appendingPathComponent(item)
                let dst = destResources.appendingPathComponent(item)
                try fm.copyItem(at: src, to: dst)
            }
            if !contents.isEmpty {
                print("  Copied Resources/ (\(contents.count) items)")
            }
        }

        print("")
        print("Bundle created: \(bundleDir.path)")

        #if os(Linux)
        print("")
        print("Note: If your app uses shared libraries, copy them to")
        print("  \(bundleDir.path)/lib/")
        print("and run: patchelf --set-rpath '$ORIGIN/lib' \(bundleDir.path)/\(product)")
        #elseif os(Windows)
        print("")
        print("Note: If your app uses DLLs, copy them next to the executable at")
        print("  \(bundleDir.path)/\(executableFilename)")
        #endif
    }

    // MARK: - macOS bundle

    private func createMacOSBundle(
        bundleDir: URL, product: String,
        executablePath: Path, fm: FileManager
    ) throws {
        let contentsDir = bundleDir.appendingPathComponent("Contents")
        let macosDir = contentsDir.appendingPathComponent("MacOS")
        let resourcesDir = contentsDir.appendingPathComponent("Resources")

        try fm.createDirectory(at: macosDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

        // Copy executable
        let destExec = macosDir.appendingPathComponent(product)
        try fm.copyItem(at: URL(fileURLWithPath: executablePath.string), to: destExec)
        print("  Executable: Contents/MacOS/\(product)")

        // Generate Info.plist
        let plist = generateInfoPlist(product: product)
        let plistPath = contentsDir.appendingPathComponent("Info.plist")
        try plist.write(to: plistPath, atomically: true, encoding: .utf8)
        print("  Info.plist generated")
    }

    // MARK: - Linux bundle

    private func createLinuxBundle(
        bundleDir: URL, product: String,
        executablePath: Path, fm: FileManager
    ) throws {
        let resourcesDir = bundleDir.appendingPathComponent("Resources")
        let libDir = bundleDir.appendingPathComponent("lib")
        try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: libDir, withIntermediateDirectories: true)

        // Copy executable to bundle root
        let destExec = bundleDir.appendingPathComponent(product)
        try fm.copyItem(at: URL(fileURLWithPath: executablePath.string), to: destExec)
        print("  Executable: \(product)")
        print("  Created: lib/ (place shared libraries here)")

        // Generate Info.json
        let info = generateInfoJson(product: product)
        let infoPath = bundleDir.appendingPathComponent("Info.json")
        try info.write(to: infoPath, atomically: true, encoding: .utf8)
        print("  Info.json generated")
    }

    // MARK: - Windows bundle

    private func createWindowsBundle(
        bundleDir: URL, product: String,
        executablePath: Path, executableFilename: String,
        fm: FileManager
    ) throws {
        let resourcesDir = bundleDir.appendingPathComponent("Resources")
        try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

        // Copy executable with its original filename (.exe)
        let destExec = bundleDir.appendingPathComponent(executableFilename)
        try fm.copyItem(at: URL(fileURLWithPath: executablePath.string), to: destExec)
        print("  Executable: \(executableFilename)")

        // Generate Info.json (executableName is the logical name, not the filename)
        let info = generateInfoJson(product: product)
        let infoPath = bundleDir.appendingPathComponent("Info.json")
        try info.write(to: infoPath, atomically: true, encoding: .utf8)
        print("  Info.json generated")
    }

    // MARK: - Metadata generation

    private func generateInfoPlist(product: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" \
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleExecutable</key>
            <string>\(product)</string>
            <key>CFBundleIdentifier</key>
            <string>com.swiftopenui.\(product.lowercased())</string>
            <key>CFBundleName</key>
            <string>\(product)</string>
            <key>CFBundleVersion</key>
            <string>1.0.0</string>
            <key>CFBundleShortVersionString</key>
            <string>1.0.0</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
        </dict>
        </plist>
        """
    }

    private func generateInfoJson(product: String) -> String {
        #if os(Windows)
        #if arch(arm64)
        let arch = "arm64"
        #else
        let arch = "x86_64"
        #endif
        #else
        #if arch(arm64)
        let arch = "aarch64"
        #else
        let arch = "x86_64"
        #endif
        #endif
        return """
        {
          "bundleIdentifier": "com.swiftopenui.\(product.lowercased())",
          "bundleName": "\(product)",
          "bundleVersion": "1.0.0",
          "executableName": "\(product)",
          "architectures": ["\(arch)"]
        }
        """
    }

    private func printUsage() {
        print("""
        USAGE: swift package create-bundle <product> [options]

        OPTIONS:
          --product <name>        Product to bundle (or pass as first argument)
          --configuration, -c     Build configuration: debug or release (default: release)
          --help                  Show this help

        EXAMPLES:
          swift package create-bundle HelloWorld
          swift package create-bundle --product HelloWorld -c debug

        NOTES:
          Architecture in Info.json is derived from the build host. For
          cross-compiled binaries, edit Info.json manually.
          On Linux, shared libraries must be manually copied to <bundle>/lib/
          and rpath set via patchelf. On Windows, DLLs must be placed next to
          the executable. See docs/guides/app-bundle-packaging.md for details.
        """)
    }
}

enum CreateBundleError: Error, CustomStringConvertible {
    case missingArgument(String)
    case unknownProduct(String)
    case notExecutable(String)
    case buildFailed(String)

    var description: String {
        switch self {
        case .missingArgument(let msg): return msg
        case .unknownProduct(let msg): return msg
        case .notExecutable(let msg): return msg
        case .buildFailed(let msg): return msg
        }
    }
}
