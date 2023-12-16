// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "ActionCableSwift",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "ActionCableSwift",
            targets: ["ActionCableSwift"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nerzh/swift-extensions-pack.git", .upToNextMajor(from: "1.16.0")),
        .package(url: "https://github.com/vapor/websocket-kit.git", .upToNextMajor(from: "2.14.0")),
    ],
    targets: [
        .target(
            name: "ActionCableSwift",
            dependencies: [
                .product(name: "SwiftExtensionsPack", package: "swift-extensions-pack"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
            ]),
    ]
)
