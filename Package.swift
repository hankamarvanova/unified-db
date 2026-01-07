// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalSQLite",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MetalSQLite",
            targets: ["MetalSQLite"]
        ),
        .executable(
            name: "MetalSQLiteDemo",
            targets: ["MetalSQLiteDemo"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MetalSQLite",
            dependencies: [],
            path: "Sources/MetalSQLite",
            resources: [
                .copy("Kernels.metal")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-feature", "-Xfrontend", "StrictConcurrency"])
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit")
            ]
        ),
        .executableTarget(
            name: "MetalSQLiteDemo",
            dependencies: ["MetalSQLite"],
            path: "Sources/MetalSQLiteDemo"
        ),
        .testTarget(
            name: "MetalSQLiteTests",
            dependencies: ["MetalSQLite"],
            path: "Tests/MetalSQLiteTests"
        )
    ]
)
