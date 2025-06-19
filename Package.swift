// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "DecentralMind",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DecentralMind",
            targets: ["DecentralMind"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.2.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift", from: "0.14.1"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift", from: "1.8.0")
    ],
    targets: [
        .target(
            name: "DecentralMind",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXOptimizers", package: "mlx-swift"),
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "CryptoSwift", package: "CryptoSwift")
            ]),
        .testTarget(
            name: "DecentralMindTests",
            dependencies: ["DecentralMind"]),
    ]
)
