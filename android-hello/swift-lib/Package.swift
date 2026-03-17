// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwiftHello",
    products: [
        .library(name: "SwiftHello", type: .dynamic, targets: ["SwiftHello"]),
    ],
    targets: [
        .target(name: "SwiftHello", path: "Sources"),
    ]
)
