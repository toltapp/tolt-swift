// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tolt",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "Tolt", targets: ["Tolt"]),
    ],
    targets: [
        .target(name: "Tolt"),
        .testTarget(name: "ToltTests", dependencies: ["Tolt"]),
    ]
)
