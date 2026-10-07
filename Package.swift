// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-libgit2-wrapper-kit",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other
        // packages.
        .library(
            name: "LibGit2WrapperKit",
            targets: ["LibGit2WrapperKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/amine2233/spm-libgit2", from: "1.9.7")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Libgit2Module",
            publicHeadersPath: "Headers",
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("iconv")
            ]
        ),
        .target(
            name: "LibGit2WrapperKit",
            dependencies: [
                .target(name: "Libgit2Module"),
                .product(name: "libgit2", package: "spm-libgit2")
            ]
        ),
        .testTarget(
            name: "GitKitTests",
            dependencies: ["LibGit2WrapperKit"]
        )
    ]
)
