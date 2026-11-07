// swift-tools-version: 6.0
import PackageDescription

// Platform-agnostic logic shared by the iOS app(s). No DAT SDK dependency,
// so it builds and tests on macOS with only the Command Line Tools
// (see scripts/test-core.sh).
let package = Package(
    name: "SidelineCore",
    platforms: [.iOS("17.2"), .macOS(.v14)],
    products: [
        .library(name: "SidelineCore", targets: ["SidelineCore"]),
    ],
    targets: [
        .target(name: "SidelineCore"),
        .testTarget(name: "SidelineCoreTests", dependencies: ["SidelineCore"]),
    ]
)
