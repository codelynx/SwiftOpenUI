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
