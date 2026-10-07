# ``LibGit2WrapperKit``

A Swift wrapper around libgit2 to clone, inspect, commit, push and pull Git repositories on iOS and macOS.

## Overview

`LibGit2WrapperKit` exposes libgit2 through a Swift API. Every operation that can fail returns a `Result<_, NSError>`, so you handle errors explicitly and nothing throws.

```swift
import LibGit2WrapperKit

let repository = try Repository.create(at: directory).get()
try repository.add(path: "README.md").get()
let commit = try repository.commit(message: "feat: first commit", author: "Jane", email: "jane@example.com").get()
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:CloneCommitPull>
- <doc:Authentication>

### Repositories

- ``Repository``
- ``Git``

### History and objects

- ``Commit``
- ``CommitIterator``
- ``Tree``
- ``Blob``
- ``Tag``
- ``OID``
- ``Signature``
- ``Diff``

### Branches, tags and remotes

- ``Branch``
- ``TagReference``
- ``ReferenceType``
- ``Remote``

### Working tree

- ``StatusEntry``
- ``StatusOptions``
- ``CheckoutStrategy``

### Authentication

- ``Credentials``
- ``ProxyConfiguration``
- ``ProxyCredential``
