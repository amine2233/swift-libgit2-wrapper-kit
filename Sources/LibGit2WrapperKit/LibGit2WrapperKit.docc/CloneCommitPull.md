# Clone, Commit and Pull

Clone a remote, record changes and keep your branch up to date.

## Clone a repository

```swift
let repository = try Repository.clone(
    from: URL(string: "https://github.com/amine2233/swift-libgit2-wrapper-kit.git")!,
    to: destinationURL,
    credentials: .default,
    proxy: nil
) { path, completed, total in
    print("checkout \(completed)/\(total) \(path ?? "")")
}.get()
```

Pass `bare: true` to clone without a working tree, for example to build a test remote. Private repositories need credentials, see <doc:Authentication>.

> Note: `localClone: true` forces the git-aware transport (`GIT_CLONE_NO_LOCAL`). Leave it at `false` to let libgit2 use its local-clone optimization when the source is a local path.

## Stage and commit

Paths are relative to the repository root.

```swift
try repository.add(path: "Sources/App.swift").get()

let commit = try repository.commit(
    message: "feat: add App",
    author: "Jane Doe",
    email: "jane@example.com"
).get()
```

To control the date and time zone, pass a ``Signature``:

```swift
let signature = Signature(name: "Jane Doe", email: "jane@example.com")
let commit = try repository.commit(message: "fix: typo", signature: signature).get()
```

The first commit of a new repository has no parent; subsequent commits use the current tip as their parent.

## Read history

```swift
let branch = try repository.localBranches().get()[0]

for result in repository.commits(in: branch) {
    let commit = try result.get()
    print(commit.oid, commit.message)
}

print(repository.numberOfCommits(in: branch))
```

## Fetch and pull

`fetch` downloads new objects and updates the remote-tracking branches:

```swift
let origin = try repository.remote(named: "origin").get()
try repository.fetch(origin, credentials: credentials, proxy: nil).get()
```

`pull` fetches, then merges the remote branch into the local one:

```swift
let branch = try repository.localBranch(named: "main").get()

try repository.pull(
    remote: origin,
    branch: branch,
    author: "Jane Doe",
    email: "jane@example.com",
    credentials: credentials,
    proxy: nil,
    conflictResolver: { ours, theirs in .ours }
).get()
```

The `conflictResolver` closure receives both versions of a conflicted file and returns a `Repository.ConflictResolutionDecision`: `.ours`, `.theirs` or `.merge(Data)` with your own resolved content.

## Push

```swift
try repository.push2(remote: origin, branch: branch, credentials: credentials).get()
```

`push2` also accepts a ``ProxyConfiguration``. `push` works the same without proxy support.

## Check out

```swift
try repository.checkout(branch).get()                 // a branch
try repository.checkout(commit.oid, strategy: .Force) // a specific commit
```

## Add, commit and push

A complete round trip, from a modified file to the remote:

```swift
let credentials = Credentials.plaintext(username: "jane", password: token)
let origin = try repository.remote(named: "origin").get()
let branch = try repository.localBranch(named: "main").get()

try "hello".write(to: directoryURL.appendingPathComponent("hello.txt"), atomically: true, encoding: .utf8)

try repository.add(path: "hello.txt").get()                    // 1. stage
let commit = try repository.commit(                            // 2. commit with a message
    message: "feat: add hello",
    author: "Jane Doe",
    email: "jane@example.com"
).get()
try repository.push2(remote: origin, branch: branch, credentials: credentials).get() // 3. push
```

## Discard what is not pushed

Two different things can be unpushed: edits that are not committed yet, and commits that were never sent to the remote.

### Discard uncommitted edits

A forced checkout of HEAD restores every tracked file to its committed content:

```swift
try repository.checkout(strategy: .Force).get()
```

Add `.RemoveUntracked` to also delete new files that were never staged:

```swift
try repository.checkout(strategy: [.Force, .RemoveUntracked]).get()
```

### Discard unpushed commits

First find out how many commits are ahead of the remote:

```swift
let branch = try repository.localBranch(named: "main").get()
let upstream = try branch.getTrackingBranch(repo: repository).get()

let (ahead, behind) = try repository.graphAheadBehind(
    localCommit: try repository.commit(branch.oid).get(),
    upstreamCommit: try repository.commit(upstream.oid).get()
).get()
print("\(ahead) commit(s) not pushed, \(behind) not pulled")
```

Then move the branch back to the remote tip with ``Repository/reset(to:type:)``:

```swift
let remoteTip = try repository.commit(upstream.oid).get()
try repository.reset(to: remoteTip).get()   // hard: drops the commits and their file changes
```

Pick the reset type to control what is kept:

| Type | Commits | Staged changes | Working tree |
| --- | --- | --- | --- |
| `.hard` (default) | dropped | dropped | restored |
| `.mixed` | dropped | dropped | kept |
| `.soft` | dropped | kept | kept |

> Warning: a hard reset cannot be undone for changes that were never committed or pushed. Use `.soft` to keep the work and recommit it differently.
