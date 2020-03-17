// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ActionCableSwift",
    products: [
        .library(
            name: "ActionCableSwift",
            targets: ["ActionCableSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nerzh/swift-extensions-pack.git", from: "0.2.6"),
    ],
    targets: [
        .target(
            name: "ActionCableSwift",
            dependencies: [
                "SwiftExtensionsPack"
            ]),
        .testTarget(
            name: "ActionCableSwiftTests",
            dependencies: ["ActionCableSwift"]),
    ]
)
