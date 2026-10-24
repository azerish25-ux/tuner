// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TimbreCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [.library(name: "TimbreCore", targets: ["TimbreCore"])],
    targets: [
        .target(name: "TimbreCore", resources: [.process("Resources")]),
        .testTarget(name: "TimbreCoreTests", dependencies: ["TimbreCore"])
    ],
    swiftLanguageModes: [.v5]
)
