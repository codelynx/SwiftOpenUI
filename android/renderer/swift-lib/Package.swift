// swift-tools-version: 5.10

// Standalone package for Android cross-compilation.
// Produces BackendAndroid.so via build-so.sh.
//
// Sources/, Tests/, and Examples/ are symlinks to the root repo:
//   Sources  -> ../../../Sources/Backend/Android/Rendering
//   Tests    -> ../../../Tests/BackendTests/AndroidTests
//   Examples -> ../../../Sources/Examples
//
// The SWIFTOPENUI_BACKEND define forces shared example views to
// import SwiftOpenUI instead of SwiftUI, even on macOS host.

import PackageDescription

let package = Package(
    name: "BackendAndroid",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "BackendAndroid", type: .dynamic, targets: ["BackendAndroid"]),
    ],
    dependencies: [
        .package(path: "../../.."),
    ],
    targets: [
        // Shared example views compiled against SwiftOpenUI (not SwiftUI)
        .target(
            name: "AndroidExamples",
            dependencies: [
                .product(name: "SwiftOpenUI", package: "SwiftOpenUI"),
            ],
            path: "Examples",
            swiftSettings: [.define("SWIFTOPENUI_BACKEND")]
        ),
        .target(
            name: "BackendAndroid",
            dependencies: [
                .product(name: "SwiftOpenUI", package: "SwiftOpenUI"),
                "AndroidExamples",
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "AndroidRenderTests",
            dependencies: [
                .product(name: "SwiftOpenUI", package: "SwiftOpenUI"),
                "BackendAndroid",
            ],
            path: "Tests"
        ),
    ]
)
