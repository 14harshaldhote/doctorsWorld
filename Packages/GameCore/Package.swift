// swift-tools-version: 6.0
import PackageDescription

// GameCore holds every game rule. It must never import UIKit, SwiftUI or
// SpriteKit, so it builds and tests on Linux and macOS alike.
let package = Package(
    name: "GameCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"])
    ],
    targets: [
        .target(name: "GameCore"),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"])
    ]
)
