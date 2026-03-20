// swift-tools-version: 5.10

import PackageDescription

var targets: [Target] = [
    // Core framework (platform-independent)
    .target(
        name: "SwiftOpenUI",
        path: "Sources/SwiftOpenUI"
    ),

    // Core tests
    .testTarget(
        name: "SwiftOpenUITests",
        dependencies: ["SwiftOpenUI"],
        path: "Tests/SwiftOpenUITests"
    ),
]

// Example runner dependencies:
// - SwiftOpenUI for the core framework
// - Backend libraries on their native platforms
var exampleDeps: [Target.Dependency] = ["SwiftOpenUI"]

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
        dependencies: ["SwiftOpenUI", "CGTK", "CGTKBridge"],
        path: "Sources/Backend/GTK4/Rendering"
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
        dependencies: ["SwiftOpenUI", "CWin32", "CWin32Bridge"],
        path: "Sources/Backend/Win32/Rendering"
    ),
    .testTarget(
        name: "Win32RenderTests",
        dependencies: ["SwiftOpenUI", "BackendWin32"],
        path: "Tests/BackendTests/Win32Tests"
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
]
exampleDeps.append("BackendWeb")
#endif

// Examples — thin runners that wire Examples views to platform entry points
targets += [
    .executableTarget(
        name: "HelloWorld",
        dependencies: exampleDeps,
        path: "Examples/Showcase/HelloWorld"
    ),
    .executableTarget(
        name: "Stopwatch",
        dependencies: exampleDeps,
        path: "Examples/Showcase/Stopwatch"
    ),
    .executableTarget(
        name: "Calculator",
        dependencies: exampleDeps,
        path: "Examples/Showcase/Calculator"
    ),
    .executableTarget(
        name: "ColorMixer",
        dependencies: exampleDeps,
        path: "Examples/Showcase/ColorMixer"
    ),
    // Parity
    .executableTarget(
        name: "ParityViewsBasic",
        dependencies: exampleDeps,
        path: "Examples/Parity/ViewsBasic"
    ),
    .executableTarget(
        name: "ParityViewsLayout",
        dependencies: exampleDeps,
        path: "Examples/Parity/ViewsLayout"
    ),
    .executableTarget(
        name: "ParityModifiers",
        dependencies: exampleDeps,
        path: "Examples/Parity/Modifiers"
    ),
    .executableTarget(
        name: "ParityStateData",
        dependencies: exampleDeps,
        path: "Examples/Parity/StateData"
    ),
    .executableTarget(
        name: "ParityNavigation",
        dependencies: exampleDeps,
        path: "Examples/Parity/Navigation"
    ),
    .executableTarget(
        name: "ParityGestures",
        dependencies: exampleDeps,
        path: "Examples/Parity/Gestures"
    ),
    .executableTarget(
        name: "ParityEnvironment",
        dependencies: exampleDeps,
        path: "Examples/Parity/Environment"
    ),
    .executableTarget(
        name: "ParityAnimation",
        dependencies: exampleDeps,
        path: "Examples/Parity/Animation"
    ),
    .executableTarget(
        name: "ParityViewsContainers",
        dependencies: exampleDeps,
        path: "Examples/Parity/ViewsContainers"
    ),
    .executableTarget(
        name: "ParityFocus",
        dependencies: exampleDeps,
        path: "Examples/Parity/Focus"
    ),
    .executableTarget(
        name: "ParityAppStructure",
        dependencies: exampleDeps,
        path: "Examples/Parity/AppStructure"
    ),
]

#if os(macOS)
let deps: [Package.Dependency] = [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.20.0"),
]
#else
let deps: [Package.Dependency] = []
#endif

let package = Package(
    name: "SwiftOpenUI",
    platforms: [.macOS(.v13)],
    products: {
        var p: [Product] = [
            .library(name: "SwiftOpenUI", targets: ["SwiftOpenUI"]),
        ]
        #if os(macOS)
        p.append(.library(name: "BackendAndroid", type: .dynamic, targets: ["BackendAndroid"]))
        #endif
        return p
    }(),
    dependencies: deps,
    targets: targets
)
