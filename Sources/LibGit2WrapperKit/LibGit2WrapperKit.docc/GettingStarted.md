# Getting Started

Add the package, then create or open a repository.

## Add the package

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/amine2233/swift-libgit2-wrapper-kit.git", branch: "main")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "LibGit2WrapperKit", package: "swift-libgit2-wrapper-kit")
        ]
    )
]
```

The package supports iOS 13+ and macOS 10.15+ and links libgit2 through the `spm-libgit2` binary package.

## Create or open a repository

```swift
import LibGit2WrapperKit

// Create a new repository
let repository = try Repository.create(at: directoryURL).get()

// Open an existing one
let existing = try Repository.at(directoryURL).get()

// Check a folder before opening it
let isRepository = try Repository.isValid(url: directoryURL).get()
```

## Handle errors

Operations return `Result<Value, NSError>`. Use `.get()` to throw, or switch on the result:

```swift
switch repository.localBranches() {
case let .success(branches):
    print(branches.map(\.name))
case let .failure(error):
    print(error.localizedDescription)
}
```

## Inspect the repository

```swift
let head = try repository.HEAD().get()
let branches = try repository.localBranches().get()
let status = try repository.status().get()

for entry in status where entry.status.contains(.workTreeModified) {
    print("modified:", entry.headToIndex?.newFile?.path ?? "")
}
```

## Next steps

- <doc:CloneCommitPull> to exchange commits with a remote.
- <doc:Authentication> to access private repositories.
