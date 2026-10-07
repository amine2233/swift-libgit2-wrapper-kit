import Foundation
import Testing
@testable import LibGit2WrapperKit

struct PushPullTests {
    private struct Fixture {
        let root: URL
        let bare: Repository
        let bareURL: URL
        let workURL: URL
        let work: Repository
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2WrapperKitTests-\(UUID().uuidString)", isDirectory: true)
        let seedURL = root.appendingPathComponent("seed")
        try FileManager.default.createDirectory(at: seedURL, withIntermediateDirectories: true)
        let seed = try Repository.create(at: seedURL).get()
        _ = try commitFile("seed.txt", in: seed, directory: seedURL)

        let bareURL = root.appendingPathComponent("remote.git")
        let bare = try Repository.clone(from: seedURL, to: bareURL, bare: true, proxy: nil).get()
        let workURL = root.appendingPathComponent("work")
        let work = try Repository.clone(from: bareURL, to: workURL, proxy: nil).get()
        return Fixture(root: root, bare: bare, bareURL: bareURL, workURL: workURL, work: work)
    }

    private func commitFile(_ name: String, in repository: Repository, directory: URL) throws -> Commit {
        try name.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        try repository.add(path: name).get()
        return try repository.commit(message: "feat: add \(name)", author: "Tester", email: "t@example.com")
            .get()
    }

    @Test
    func pushPublishesLocalCommitToRemote() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let commit = try commitFile("pushed.txt", in: fixture.work, directory: fixture.workURL)
        let origin = try fixture.work.remote(named: "origin").get()
        let branch = try #require(try fixture.work.localBranches().get().first)

        try fixture.work.push(remote: origin, branch: branch).get()

        let remoteBranch = try #require(try fixture.bare.localBranches().get()
            .first { $0.name == branch.name })
        #expect(remoteBranch.oid == commit.oid)
    }

    @Test
    func push2PublishesLocalCommitToRemote() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let commit = try commitFile("pushed2.txt", in: fixture.work, directory: fixture.workURL)
        let origin = try fixture.work.remote(named: "origin").get()
        let branch = try #require(try fixture.work.localBranches().get().first)

        try fixture.work.push2(remote: origin, branch: branch).get()

        let remoteBranch = try #require(try fixture.bare.localBranches().get()
            .first { $0.name == branch.name })
        #expect(remoteBranch.oid == commit.oid)
    }

    @Test
    func fetchedCommitIsVisibleOnRemoteTrackingBranch() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let otherURL = fixture.root.appendingPathComponent("other")
        let other = try Repository.clone(from: fixture.bareURL, to: otherURL, proxy: nil).get()
        let commit = try commitFile("from-other.txt", in: other, directory: otherURL)
        let origin = try other.remote(named: "origin").get()
        try other.push(remote: origin, branch: #require(try other.localBranches().get().first)).get()

        try fixture.work.fetch(fixture.work.remote(named: "origin").get(), proxy: nil).get()

        #expect(try fixture.work.remoteBranches().get().map(\.oid).contains(commit.oid))
    }

    @Test
    func pullFastForwardsLocalBranch() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let otherURL = fixture.root.appendingPathComponent("other")
        let other = try Repository.clone(from: fixture.bareURL, to: otherURL, proxy: nil).get()
        let commit = try commitFile("from-other.txt", in: other, directory: otherURL)
        try other.push2(
            remote: other.remote(named: "origin").get(),
            branch: #require(try other.localBranches().get().first)
        ).get()
        let origin = try fixture.work.remote(named: "origin").get()
        let branch = try #require(try fixture.work.localBranches().get().first)

        try fixture.work.pull(
            remote: origin,
            branch: branch,
            author: "Tester",
            email: "t@example.com",
            proxy: nil,
            conflictResolver: { _, _ in .ours }
        ).get()

        #expect(try fixture.work.HEAD().get().oid == commit.oid)
        #expect(FileManager.default
            .fileExists(atPath: fixture.workURL.appendingPathComponent("from-other.txt").path))
    }

    @Test
    func commitIteratorWalksHistoryNewestFirst() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let second = try commitFile("second.txt", in: fixture.work, directory: fixture.workURL)
        let branch = try #require(try fixture.work.localBranches().get().first)

        let commits = try fixture.work.commits(in: branch).map { try $0.get() }

        #expect(commits.count == 2)
        #expect(commits.first?.oid == second.oid)
    }

    @Test
    func modifiedTrackedFileIsReportedAsWorkTreeModified() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try "changed".write(
            to: fixture.workURL.appendingPathComponent("seed.txt"),
            atomically: true,
            encoding: .utf8
        )

        let entries = try fixture.work.status().get()

        #expect(entries.contains { $0.status.contains(.workTreeModified) })
    }

    @Test
    func checkoutRemoteBranchDetachesHeadAtItsTip() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let remoteBranch = try #require(try fixture.work.remoteBranches().get()
            .first { !$0.name.hasSuffix("HEAD") })

        try fixture.work.checkout(remoteBranch).get()

        #expect(try fixture.work.HEAD().get().longName == "HEAD")
        #expect(try fixture.work.HEAD().get().oid == remoteBranch.oid)
    }
}
