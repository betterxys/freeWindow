// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FreeWindow",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "FreeWindow", targets: ["FreeWindow"]),
        .executable(name: "FreeWindowTestRunner", targets: ["FreeWindowTestRunner"]),
    ],
    targets: [
        // Core pure-logic library (no AppKit dependency needed for tests)
        .target(
            name: "FreeWindowCore",
            path: "FreeWindow/Core"
        ),
        // Main app executable
        .executableTarget(
            name: "FreeWindow",
            dependencies: ["FreeWindowCore"],
            path: "FreeWindow",
            exclude: ["Resources/Assets.xcassets", "Resources/Info.plist", "Core"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        ),
        // Test runner (standalone executable, no XCTest needed)
        .executableTarget(
            name: "FreeWindowTestRunner",
            dependencies: ["FreeWindowCore"],
            path: "FreeWindowTests"
        ),
    ]
)
