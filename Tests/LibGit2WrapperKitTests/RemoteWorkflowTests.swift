import Foundation
import Testing
@testable import LibGit2WrapperKit

struct RemoteWorkflowTests {
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2WrapperKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func commitFile(_ name: String, in repository: Repository, directory: URL) throws -> Commit {
        try name.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        try repository.add(path: name).get()
        return try repository.commit(message: "feat: add \(name)", author: "Tester", email: "t@example.com")
            .get()
    }

    @Test
    func cloneCopiesHistoryAndRegistersOrigin() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceURL = root.appendingPathComponent("source")
        let cloneURL = root.appendingPathComponent("clone")
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        let source = try Repository.create(at: sourceURL).get()
        let commit = try commitFile("a.txt", in: source, directory: sourceURL)

        let clone = try Repository.clone(from: sourceURL, to: cloneURL, proxy: nil).get()

        #expect(try clone.HEAD().get().oid == commit.oid)
        #expect(try clone.allRemotes().get().map(\.name) == ["origin"])
        #expect(FileManager.default.fileExists(atPath: cloneURL.appendingPathComponent("a.txt").path))
        #expect(try clone.remoteBranches().get()
            .contains { try $0.name.hasSuffix("origin/\(clone.localBranches().get()[0].name)") })
    }

    @Test
    func fetchBringsNewRemoteCommits() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceURL = root.appendingPathComponent("source")
        let cloneURL = root.appendingPathComponent("clone")
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        let source = try Repository.create(at: sourceURL).get()
        _ = try commitFile("a.txt", in: source, directory: sourceURL)
        let clone = try Repository.clone(from: sourceURL, to: cloneURL, proxy: nil).get()
        let newCommit = try commitFile("b.txt", in: source, directory: sourceURL)

        let origin = try clone.remote(named: "origin").get()
        try clone.fetch(origin, proxy: nil).get()

        let remoteTips = try clone.remoteBranches().get().map(\.oid)
        #expect(remoteTips.contains(newCommit.oid))
    }

    @Test
    func checkoutOfOlderCommitRestoresWorkingTree() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try Repository.create(at: root).get()
        let first = try commitFile("a.txt", in: repository, directory: root)
        _ = try commitFile("b.txt", in: repository, directory: root)

        try repository.checkout(first.oid, strategy: .Force).get()

        #expect(try repository.HEAD().get().oid == first.oid)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("b.txt").path))
    }

    @Test
    func treeAndBlobLookupReturnCommittedContent() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try Repository.create(at: root).get()
        let commit = try commitFile("a.txt", in: repository, directory: root)

        let tree = try repository.tree(commit.tree.oid).get()
        let entry = try #require(tree.entries["a.txt"])
        let blob = try repository.blob(entry.object.oid).get()

        #expect(String(decoding: blob.data, as: UTF8.self) == "a.txt")
    }

    @Test
    func lookupOfUnknownObjectFails() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = try Repository.create(at: root).get()
        let unknown = try #require(OID(string: String(repeating: "a", count: 40)))

        #expect(throws: (any Error).self) { try repository.commit(unknown).get() }
        #expect(throws: (any Error).self) { try repository.reference(named: "refs/heads/missing").get() }
    }
}
