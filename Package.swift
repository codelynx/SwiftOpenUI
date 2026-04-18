// swift-tools-version: 5.10

import PackageDescription

var targets: [Target] = [
    // Core framework (platform-independent)
    .target(
        name: "SwiftOpenUI",
        path: "Sources/SwiftOpenUI"
    ),

    // Small helper module for macOS example launch boilerplate.
    .target(
        name: "MacExampleSupport",
        path: "Sources/MacExampleSupport"
    ),

    // Core tests
    .testTarget(
        name: "SwiftOpenUITests",
        dependencies: ["SwiftOpenUI"],
        path: "Tests/SwiftOpenUITests"
    ),

    // Layout parity — shared snapshot model (platform-independent)
    .target(
        name: "LayoutParityShared",
        dependencies: [],
        path: "Tests/LayoutParityTests/Shared"
    ),
    // Layout parity — comparison logic unit tests (platform-independent)
    .testTarget(
        name: "LayoutParityComparisonTests",
        dependencies: ["LayoutParityShared"],
        path: "Tests/LayoutParityTests/ComparisonTests"
    ),

    // Bundled icon font resources for non-macOS backends. Ungated so
    // Windows / Web / Android backends can declare it as a dependency
    // alongside GTK4. macOS targets continue to use native SF Symbols
    // via real SwiftUI and never consume this target.
    .target(
        name: "SwiftOpenUISymbols",
        path: "Sources/SwiftOpenUISymbols",
        resources: [
            .copy("Resources/MaterialSymbolsRounded-Regular.ttf"),
            .copy("Resources/LICENSES"),
            .copy("Resources/README.md"),
        ]
    ),
]

// Example runner dependencies:
// - SwiftOpenUI for the core framework
// - Backend libraries on their native platforms
var exampleDeps: [Target.Dependency] = ["SwiftOpenUI", "MacExampleSupport"]

// GTK4 backend (Linux)
#if os(Linux)
targets += [
    .systemLibrary(
        name: "CGTK",
        path: "Sources/Backend/GTK4/CGTK",
        pkgConfig: "gtk4",
        providers: [.apt(["libgtk-4-dev"])]
    ),
    .target(
        name: "CGTKBridge",
        dependencies: ["CGTK"],
        path: "Sources/Backend/GTK4/CGTKBridge"
    ),
    .target(
        name: "BackendGTK4",
        dependencies: ["SwiftOpenUI", "CGTK", "CGTKBridge", "SwiftOpenUISymbols"],
        path: "Sources/Backend/GTK4/Rendering",
        linkerSettings: [
            // FontConfig is used by the process-local font registration
            // path that loads SwiftOpenUISymbols' bundled Material Symbols
            // font. GTK/Pango pull libfontconfig in transitively for
            // runtime calls but pkg-config's --libs gtk4 doesn't name
            // it explicitly at link time; declare it here to keep the
            // FcConfig* symbols resolvable.
            .linkedLibrary("fontconfig"),
        ]
    ),
    .testTarget(
        name: "GTK4RenderTests",
        dependencies: ["SwiftOpenUI", "BackendGTK4", "CGTK", "CGTKBridge"],
        path: "Tests/BackendTests/GTK4Tests"
    ),
    // Layout parity — GTK comparison against macOS reference
    .testTarget(
        name: "GTKLayoutParityTests",
        dependencies: ["SwiftOpenUI", "BackendGTK4", "CGTK", "CGTKBridge", "LayoutParityShared"],
        path: "Tests/LayoutParityTests/GTKComparison"
    ),
]
exampleDeps.append("BackendGTK4")
#endif

// Win32 backend (Windows)
#if os(Windows)
targets += [
    .target(
        name: "CWin32",
        path: "Sources/Backend/Win32/CWin32",
        publicHeadersPath: "include",
        linkerSettings: [
            .linkedLibrary("comctl32"),
            .linkedLibrary("user32"),
            .linkedLibrary("gdi32"),
            .linkedLibrary("d2d1"),
            .linkedLibrary("dwrite"),
            .linkedLibrary("windowscodecs"),
            .linkedLibrary("ole32"),
        ]
    ),
    .target(
        name: "CWin32Bridge",
        dependencies: ["CWin32"],
        path: "Sources/Backend/Win32/CWin32Bridge"
    ),
    .target(
        name: "BackendWin32",
        dependencies: ["SwiftOpenUI", "CWin32", "CWin32Bridge", "SwiftOpenUISymbols"],
        path: "Sources/Backend/Win32/Rendering"
    ),
    .testTarget(
        name: "Win32RenderTests",
        dependencies: ["SwiftOpenUI", "BackendWin32"],
        path: "Tests/BackendTests/Win32Tests"
    ),
    // Layout parity — Win32 comparison against macOS reference
    .testTarget(
        name: "Win32LayoutParityTests",
        dependencies: ["SwiftOpenUI", "BackendWin32", "CWin32", "CWin32Bridge", "LayoutParityShared"],
        path: "Tests/LayoutParityTests/Win32Comparison"
    ),
]
exampleDeps.append("BackendWin32")
#endif

// Android backend — temporarily in root for cross-compilation testing
#if os(macOS)
targets += [
    .target(
        name: "BackendAndroid",
        dependencies: ["SwiftOpenUI"],
        path: "Sources/Backend/Android/Rendering"
    ),
    .testTarget(
        name: "AndroidRenderTests",
        dependencies: ["SwiftOpenUI", "BackendAndroid"],
        path: "Tests/BackendTests/AndroidTests"
    ),
    // Layout parity — macOS reference capture (uses real SwiftUI)
    .testTarget(
        name: "MacOSLayoutReferenceTests",
        dependencies: ["SwiftOpenUI", "LayoutParityShared"],
        path: "Tests/LayoutParityTests/MacOSReference"
    ),
]
#endif

// Web backend (WebAssembly)
// Gated to macOS host — Wasm cross-compilation always happens from macOS.
// On Linux, this avoids pulling JavaScriptKit into native GTK builds.
#if os(macOS)
targets += [
    .target(
        name: "BackendWeb",
        dependencies: [
            "SwiftOpenUI",
            .product(name: "JavaScriptKit", package: "JavaScriptKit"),
        ],
        path: "Sources/Backend/Web/Rendering"
    ),
    .testTarget(
        name: "WebDescriptorTests",
        dependencies: ["SwiftOpenUI", "BackendWeb"],
        path: "Tests/BackendTests/WebTests"
    ),
]
exampleDeps.append("BackendWeb")
#endif

// Wasm linker settings: increase linear memory for debug builds.
// Default Wasm memory is too small for view trees with many modifiers.
var exampleLinkerSettings: [LinkerSetting] = [
    .unsafeFlags([
        "-Xlinker", "--initial-memory=134217728",  // 128 MB (debug binaries need ~38 MB)
        "-Xlinker", "--max-memory=268435456",      // 256 MB growable
    ], .when(platforms: [.wasi]))
]

// Examples — thin runners that wire Examples views to platform entry points
targets += [
    .executableTarget(
        name: "HelloWorld",
        dependencies: exampleDeps,
        path: "Examples/Showcase/HelloWorld",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "Stopwatch",
        dependencies: exampleDeps,
        path: "Examples/Showcase/Stopwatch",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "Calculator",
        dependencies: exampleDeps,
        path: "Examples/Showcase/Calculator",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ColorMixer",
        dependencies: exampleDeps,
        path: "Examples/Showcase/ColorMixer",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "SimplePaint",
        dependencies: exampleDeps,
        path: "Examples/Showcase/SimplePaint",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "LayoutStress",
        dependencies: exampleDeps,
        path: "Examples/Showcase/LayoutStress",
        linkerSettings: exampleLinkerSettings
    ),
    // Parity
    .executableTarget(
        name: "ParityViewsBasic",
        dependencies: exampleDeps,
        path: "Examples/Parity/ViewsBasic",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityViewsLayout",
        dependencies: exampleDeps,
        path: "Examples/Parity/ViewsLayout",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityModifiers",
        dependencies: exampleDeps,
        path: "Examples/Parity/Modifiers",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityStateData",
        dependencies: exampleDeps,
        path: "Examples/Parity/StateData",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityNavigation",
        dependencies: exampleDeps,
        path: "Examples/Parity/Navigation",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityGestures",
        dependencies: exampleDeps,
        path: "Examples/Parity/Gestures",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityEnvironment",
        dependencies: exampleDeps,
        path: "Examples/Parity/Environment",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityAnimation",
        dependencies: exampleDeps,
        path: "Examples/Parity/Animation",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityViewsContainers",
        dependencies: exampleDeps,
        path: "Examples/Parity/ViewsContainers",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityFocus",
        dependencies: exampleDeps,
        path: "Examples/Parity/Focus",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityAppStructure",
        dependencies: exampleDeps,
        path: "Examples/Parity/AppStructure",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityKeyboardShortcut",
        dependencies: exampleDeps,
        path: "Examples/Parity/KeyboardShortcut",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityCommands",
        dependencies: exampleDeps,
        path: "Examples/Parity/Commands",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "ParityDropDestination",
        dependencies: exampleDeps,
        path: "Examples/Parity/DropDestination",
        linkerSettings: exampleLinkerSettings
    ),
    .executableTarget(
        name: "Win32ReviewSmoke",
        dependencies: exampleDeps,
        path: "Examples/Smoke/Win32Review",
        linkerSettings: exampleLinkerSettings
    ),
]

// M-Symbols-1 minimum-viable proof: bundled font loads into FontConfig
// process-locally and Pango renders a glyph by family name. Active on all
// platforms: macOS renders SF Symbol equivalents via the same example
// (SwiftUI-canonical); non-macOS backends render Material glyphs via
// Image(material:) against the SwiftOpenUISymbols font.
targets += [
    .executableTarget(
        name: "ParityMaterialSymbols",
        dependencies: exampleDeps,
        path: "Examples/Parity/MaterialSymbols",
        linkerSettings: exampleLinkerSettings
    ),
]

#if os(macOS)
let deps: [Package.Dependency] = [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.20.0"),
]
#else
let deps: [Package.Dependency] = []
#endif

// App bundle packaging plugin
targets.append(
    .plugin(
        name: "CreateBundle",
        capability: .command(
            intent: .custom(verb: "create-bundle", description: "Package an executable as a .app bundle"),
            permissions: [.writeToPackageDirectory(reason: "Creates .build/bundles/<Product>.app")]
        ),
        path: "Plugins/CreateBundle"
    )
)

let package = Package(
    name: "SwiftOpenUI",
    platforms: [.macOS(.v14)],
    products: {
        var p: [Product] = [
            .library(name: "SwiftOpenUI", targets: ["SwiftOpenUI"]),
        ]
        #if os(Linux)
        p.append(.library(name: "CGTK", targets: ["CGTK"]))
        p.append(.library(name: "CGTKBridge", targets: ["CGTKBridge"]))
        p.append(.library(name: "BackendGTK4", targets: ["BackendGTK4"]))
        // SwiftOpenUISymbols is consumed transitively by BackendGTK4, but
        // also exposed as an importable product so apps can reference
        // `MaterialSymbolsResources` directly (e.g. to surface the bundled
        // license text in an About dialog or to perform custom font lookups).
        p.append(.library(name: "SwiftOpenUISymbols", targets: ["SwiftOpenUISymbols"]))
        #endif
        #if os(Windows)
        p.append(.library(name: "CWin32", targets: ["CWin32"]))
        p.append(.library(name: "CWin32Bridge", targets: ["CWin32Bridge"]))
        p.append(.library(name: "BackendWin32", targets: ["BackendWin32"]))
        // Same rationale as Linux: expose SwiftOpenUISymbols so apps can
        // reference MaterialSymbolsResources directly.
        p.append(.library(name: "SwiftOpenUISymbols", targets: ["SwiftOpenUISymbols"]))
        #endif
        #if os(macOS)
        p.append(.library(name: "BackendAndroid", type: .dynamic, targets: ["BackendAndroid"]))
        #endif
        return p
    }(),
    dependencies: deps,
    targets: targets
)
