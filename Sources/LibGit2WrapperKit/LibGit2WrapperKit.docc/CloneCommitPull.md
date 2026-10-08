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

## Use async/await

`clone`, `fetch`, `push` and `pull` have `async throws` overloads that run the blocking libgit2 call off the caller's executor, so you can `await` them from the main actor without freezing the UI:

```swift
let repository = try await Repository.clone(from: remoteURL, to: destinationURL, credentials: credentials, proxy: nil)
let origin = try repository.remote(named: "origin").get()

try await repository.fetch(origin, credentials: credentials, proxy: nil)
try await repository.push(remote: origin, branch: branch, credentials: credentials)
```

> Important: do not run two operations on the same ``Repository`` at once. libgit2 repository handles are not safe for concurrent use.

## Show clone progress

The `checkoutProgress` closure of `clone` reports the checkout phase as `(path, completedSteps, totalSteps)`. Use it to drive a SwiftUI progress bar:

```swift
import LibGit2WrapperKit
import SwiftUI

@MainActor @Observable
final class CloneViewModel {
    var fractionCompleted = 0.0
    var isCloning = false
    var errorMessage: String?

    func clone(from remoteURL: URL, to destinationURL: URL) async {
        isCloning = true
        defer { isCloning = false }

        do {
            _ = try await Repository.clone(from: remoteURL, to: destinationURL, proxy: nil) { [weak self] _, completed, total in
                guard total > 0 else { return }
                let fraction = Double(completed) / Double(total)
                Task { @MainActor in self?.fractionCompleted = fraction }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CloneView: View {
    @State private var model = CloneViewModel()
    let remoteURL: URL
    let destinationURL: URL

    var body: some View {
        VStack {
            if model.isCloning {
                ProgressView(value: model.fractionCompleted)
            } else {
                Button("Clone") {
                    Task { await model.clone(from: remoteURL, to: destinationURL) }
                }
            }
            if let message = model.errorMessage {
                Text(message).foregroundStyle(.red)
            }
        }
    }
}
```

> Important: this bar only covers the checkout phase, which starts after the objects are downloaded. During the download of a large repository it stays at zero, and cloning from a local path has no download phase at all. Download progress is not exposed by the library yet.

## Get the full history

``Repository/commits(in:)`` walks one branch from newest to oldest. To list every commit of the repository, walk all local and remote branches and keep each commit once:

```swift
struct HistoryEntry {
    let id: OID
    let summary: String
    let author: String
    let date: Date
    let changedFiles: [String]
}

func fullHistory(of repository: Repository) throws -> [HistoryEntry] {
    let branches = try repository.localBranches().get() + repository.remoteBranches().get()

    var seen = Set<OID>()
    var entries: [HistoryEntry] = []
    for branch in branches {
        for result in repository.commits(in: branch) {
            let commit = try result.get()
            guard seen.insert(commit.oid).inserted else { continue }

            let diff = try repository.diff(for: commit).get()
            entries.append(
                HistoryEntry(
                    id: commit.oid,
                    summary: commit.message.split(separator: "\n").first.map(String.init) ?? "",
                    author: commit.author.name,
                    date: commit.author.time,
                    changedFiles: diff.deltas.compactMap { $0.newFile?.path }
                )
            )
        }
    }
    return entries.sorted { $0.date > $1.date }
}
```

Each commit exposes its ``Commit/author``, ``Commit/committer``, ``Commit/message``, ``Commit/parents`` and ``Commit/tree``. ``Repository/diff(for:)`` lists the files that commit changed.

> Tip: a cloned repository only has the branches the remote advertises. Run `fetch` first if you want history that was pushed after the clone.

> Note: computing a diff per commit is the expensive part on a large repository. Drop the `diff(for:)` call if you only need messages and authors, or compute it lazily when the user opens a commit.
