// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StressCore",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v13)],
    products: [.library(name: "StressCore", targets: ["StressCore"])],
    targets: [
        .target(name: "StressCore"),
        .testTarget(name: "StressCoreTests", dependencies: ["StressCore"])
    ]
)

