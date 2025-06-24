// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "slunk",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SlunkCore",
            targets: ["SlunkCore"]
        ),
    ],
    dependencies: [
        // MCP Swift SDK
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        // SQLite for relational data
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.5.0"),
        // SQLiteVec for vector storage
        .package(url: "https://github.com/jkrukowski/SQLiteVec.git", from: "0.0.9"),
    ],
    targets: [
        .target(
            name: "SlunkCore",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SQLiteVec", package: "SQLiteVec"),
            ]
        ),
        .testTarget(
            name: "SlunkCoreTests",
            dependencies: ["SlunkCore"]
        ),
    ]
)