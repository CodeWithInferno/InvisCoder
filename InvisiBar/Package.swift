// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InvisiBar",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-markdown.git", from: "0.3.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "InvisiBar",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ]
        ),
    ]
)
