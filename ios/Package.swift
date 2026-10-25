// swift-tools-version: 6.0
import PackageDescription

// Complete concurrency checking, as warnings in the Swift 5 language mode, while each file's owner clears them; the
// package moves to `.v6` once the CI warnings gate (tools/ci/build_warnings.py) counts none in TimbreCore.
let strictConcurrency: [SwiftSetting] = [.enableUpcomingFeature("StrictConcurrency")]

let package = Package(
    name: "TimbreCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "TimbreCore", targets: ["TimbreCore"])],
    targets: [
        .target(name: "TimbreCore", resources: [.process("Resources")], swiftSettings: strictConcurrency),
        .testTarget(name: "TimbreCoreTests", dependencies: ["TimbreCore"], swiftSettings: strictConcurrency)
    ],
    swiftLanguageModes: [.v5]
)
