// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DesignKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "DesignKit", targets: ["DesignKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/vector-im/compound-ios.git", revision: "a6aec9a77bf008c86a296ba17d60005b5a8bfae4"),
        .package(url: "https://github.com/vector-im/element-design-tokens.git", exact: "0.0.3"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "0.1.4")
    ],
    targets: [
        .target(name: "DesignKit",
                dependencies: [
                    .product(name: "Compound", package: "compound-ios"),
                    .product(name: "DesignTokens", package: "element-design-tokens"),
                    .product(name: "Introspect", package: "SwiftUI-Introspect")
                ],
                path: "Sources"),
        .testTarget(name: "DesignKitTests",
                    dependencies: ["DesignKit"],
                    path: "Tests")
    ]
)
