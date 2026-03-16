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

#if os(macOS)
var exampleDeps: [Target.Dependency] = []
#else
var exampleDeps: [Target.Dependency] = ["SwiftOpenUI"]
#endif

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

let package = Package(
    name: "SwiftOpenUI",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "SwiftOpenUI", targets: ["SwiftOpenUI"]),
    ],
    targets: targets
)
