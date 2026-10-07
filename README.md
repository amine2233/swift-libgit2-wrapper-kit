# swift-libgit2-wrapper-kit

Swift wrapper around [libgit2](https://libgit2.org) for iOS and macOS. It exposes repositories, branches, commits, trees, blobs, diffs, remotes, references and credentials through a Swift API.

## Installation

### Swift Package Manager

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/amine2233/swift-libgit2-wrapper-kit.git", from: "1.0.0")
]
```

Then add the product to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "LibGit2WrapperKit", package: "swift-libgit2-wrapper-kit")
    ]
)
```

In Xcode: **File > Add Package Dependencies…** and enter `https://github.com/amine2233/swift-libgit2-wrapper-kit.git`.

### Requirements

- Swift 6.1+
- iOS 13+ / macOS 10.15+

## Development

```bash
mise test
```

## License

Released under the MIT License. See [LICENSE](LICENSE).
