// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "HP", platforms: [.macOS(.v13), .iOS(.v17), .watchOS(.v10)], products: [.library(name: "HPCore", targets: ["HPCore"])], targets: [.target(name: "HPCore"), .testTarget(name: "HPCoreTests", dependencies: ["HPCore"])])
