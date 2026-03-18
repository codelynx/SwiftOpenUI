// swift-tools-version: 5.10

import PackageDescription

var targets: [Target] = [
    // Core framework (platform-independent)
    .target(
        name: "SwiftOpenUI",
        path: "Sources/SwiftOpenUI"
    ),

    // Shared example views (imported by all runners and Android JNI)
    // On macOS: #if canImport(SwiftUI) selects real SwiftUI
    // On other platforms: imports SwiftOpenUI
    .target(
        name: "ExamplesShared",
        dependencies: ["SwiftOpenUI"],
        path: "Sources/ExamplesShared"
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

// Android backend
// Gated to macOS host — Android cross-compilation happens from macOS.
// Produces a .so with JNI entry points; no platform-specific system deps.
#if os(macOS)
targets += [
    .target(
        name: "BackendAndroid",
        dependencies: ["SwiftOpenUI", "ExamplesShared"],
        path: "Sources/Backend/Android/Rendering"
    ),
    .testTarget(
        name: "AndroidRenderTests",
        dependencies: ["SwiftOpenUI", "BackendAndroid", "ExamplesShared"],
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

// Examples — thin runners that wire ExamplesShared views to platform entry points
targets += [
    .executableTarget(
        name: "HelloWorld",
        dependencies: exampleDeps,
        path: "Examples/HelloWorld"
    ),
    .executableTarget(
        name: "Counter",
        dependencies: exampleDeps,
        path: "Examples/Counter"
    ),
    .executableTarget(
        name: "Showcase1",
        dependencies: exampleDeps,
        path: "Examples/Showcase1"
    ),
    .executableTarget(
        name: "Showcase2",
        dependencies: exampleDeps,
        path: "Examples/Showcase2"
    ),
    .executableTarget(
        name: "TextStyles",
        dependencies: exampleDeps,
        path: "Examples/02-TextStyles"
    ),
    .executableTarget(
        name: "Buttons",
        dependencies: exampleDeps,
        path: "Examples/03-Buttons"
    ),
    .executableTarget(
        name: "StateDemo",
        dependencies: exampleDeps,
        path: "Examples/04-State"
    ),
    .executableTarget(
        name: "FocusTest",
        dependencies: exampleDeps,
        path: "Examples/FocusTest"
    ),
    .executableTarget(
        name: "BasicInteractive",
        dependencies: exampleDeps,
        path: "Examples/BasicInteractive"
    ),
    .executableTarget(
        name: "Layout",
        dependencies: exampleDeps,
        path: "Examples/05-Layout"
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
            .library(name: "ExamplesShared", targets: ["ExamplesShared"]),
        ]
        #if os(macOS)
        p.append(.library(name: "BackendAndroid", type: .dynamic, targets: ["BackendAndroid"]))
        #endif
        return p
    }(),
    dependencies: deps,
    targets: targets
)
