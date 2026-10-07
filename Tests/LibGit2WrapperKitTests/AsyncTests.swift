import Foundation
import Testing
@testable import LibGit2WrapperKit

struct AsyncTests {
    private func makeSource() throws -> (root: URL, url: URL, repository: Repository) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2WrapperKitTests-\(UUID().uuidString)", isDirectory: true)
        let url = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let repository = try Repository.create(at: url).get()
        try commitFile("seed.txt", in: repository, directory: url)
        return (root, url, repository)
    }

    @discardableResult
    private func commitFile(_ name: String, in repository: Repository, directory: URL) throws -> Commit {
        try name.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        try repository.add(path: name).get()
        return try repository.commit(message: "feat: add \(name)", author: "Tester", email: "t@example.com")
            .get()
    }

    @Test
    func asyncCloneFetchPushAndPullRoundTrip() async throws {
        let source = try makeSource()
        defer { try? FileManager.default.removeItem(at: source.root) }
        let bareURL = source.root.appendingPathComponent("remote.git")
        _ = try await Repository.clone(from: source.url, to: bareURL, bare: true, proxy: nil)

        let aURL = source.root.appendingPathComponent("a")
        let bURL = source.root.appendingPathComponent("b")
        let a = try await Repository.clone(from: bareURL, to: aURL, proxy: nil)
        let b = try await Repository.clone(from: bareURL, to: bURL, proxy: nil)

        let commit = try commitFile("from-a.txt", in: a, directory: aURL)
        let aBranch = try #require(try a.localBranches().get().first)
        try await a.push(remote: a.remote(named: "origin").get(), branch: aBranch)

        let origin = try b.remote(named: "origin").get()
        try await b.fetch(origin, proxy: nil)
        #expect(try b.remoteBranches().get().map(\.oid).contains(commit.oid))

        let bBranch = try #require(try b.localBranches().get().first)
        try await b.pull(
            remote: origin,
            branch: bBranch,
            author: "Tester",
            email: "t@example.com",
            proxy: nil,
            conflictResolver: { _, _ in .ours }
        )
        #expect(try b.HEAD().get().oid == commit.oid)
    }

    @Test
    func asyncCloneOfMissingSourceThrows() async throws {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)")
        let target = FileManager.default.temporaryDirectory
            .appendingPathComponent("target-\(UUID().uuidString)")

        await #expect(throws: (any Error).self) {
            _ = try await Repository.clone(from: missing, to: target, proxy: nil)
        }
    }
}
