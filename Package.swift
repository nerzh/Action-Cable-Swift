// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "ActionCableSwift",
    platforms: [
        .macOS(.v10_13),
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "ActionCableSwift",
            targets: ["ActionCableSwift"]),
    ],
    dependencies: [
        .package(name: "SwiftExtensionsPack",
                 url: "https://github.com/nerzh/swift-extensions-pack.git", .upToNextMajor(from: "0.5.0")),
    ],
    targets: [
        .target(
            name: "ActionCableSwift",
            dependencies: [
                .product(name: "SwiftExtensionsPack", package: "SwiftExtensionsPack")
            ]),
        .testTarget(
            name: "ActionCableSwiftTests",
            dependencies: ["ActionCableSwift"]),
    ]
)
