// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwiftOpenUI",
    products: [
        .library(name: "SwiftOpenUI", targets: ["SwiftOpenUI"]),
    ],
    targets: [
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

        // Examples
        .executableTarget(
            name: "HelloWorld",
            dependencies: ["SwiftOpenUI"],
            path: "Examples/HelloWorld"
        ),
        .executableTarget(
            name: "Counter",
            dependencies: ["SwiftOpenUI"],
            path: "Examples/Counter"
        ),
        .executableTarget(
            name: "Showcase1",
            dependencies: ["SwiftOpenUI"],
            path: "Examples/Showcase1"
        ),
        .executableTarget(
            name: "Showcase2",
            dependencies: ["SwiftOpenUI"],
            path: "Examples/Showcase2"
        ),
    ]
)

// TODO: Conditional backend targets per platform
// #if os(Linux)
//     package.targets.append(.target(name: "BackendGTK4", path: "Sources/Backend/GTK4"))
// #elseif os(Windows)
//     package.targets.append(.target(name: "BackendWin32", path: "Sources/Backend/Win32"))
// #endif
