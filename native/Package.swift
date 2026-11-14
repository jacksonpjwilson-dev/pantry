// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "PantryCore", platforms: [.iOS(.v17), .macOS(.v13)], products: [.library(name: "PantryCore", targets: ["PantryCore"])], targets: [.target(name: "PantryCore", path: "PantryCore"), .testTarget(name: "PantryCoreTests", dependencies: ["PantryCore"], path: "PantryCoreTests")])
