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

// Always include SwiftOpenUI — examples use #if os(macOS) in source
// to select SwiftUI vs SwiftOpenUI. Manifest #if os() checks the HOST
// platform, not the cross-compilation target, so we can't gate here.
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

// Web backend (WebAssembly)
// Always declared — manifest #if arch() checks HOST, not cross-compile target.
// JavaScriptKit is only resolved when building for wasm32.
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

// Examples
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
]

let deps: [Package.Dependency] = [
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.20.0"),
]

let package = Package(
    name: "SwiftOpenUI",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftOpenUI", targets: ["SwiftOpenUI"]),
    ],
    dependencies: deps,
    targets: targets
)
