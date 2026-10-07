import Foundation
import Testing
@testable import LibGit2WrapperKit

struct RepositoryTests {
    private func makeRepository() throws -> (repository: Repository, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2WrapperKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let repository = try Repository.create(at: directory).get()
        return (repository, directory)
    }

    private func commitFile(
        named name: String,
        contents: String = "content",
        message: String = "feat: add file",
        in repository: Repository,
        directory: URL
    ) throws -> Commit {
        try contents.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
        try repository.add(path: name).get()
        return try repository.commit(message: message, author: "Tester", email: "tester@example.com").get()
    }

    @Test
    func versionIsNotEmpty() {
        #expect(!Git.version().isEmpty)
    }

    @Test
    func createdRepositoryIsValidAndReopenable() throws {
        let (_, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(try Repository.isValid(url: directory).get())
        let reopened = try Repository.at(directory).get()
        #expect(reopened.directoryURL?.standardizedFileURL.path == directory.standardizedFileURL.path)
    }

    @Test
    func directoryWithoutRepositoryIsNotValid() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2WrapperKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(try Repository.isValid(url: directory).get() == false)
        #expect(throws: (any Error).self) { try Repository.at(directory).get() }
    }

    @Test
    func untrackedFileAppearsInStatus() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }
        try "hello".write(to: directory.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)

        let entries = try repository.status().get()

        #expect(entries.count == 1)
        #expect(entries.first?.status.contains(.workTreeNew) == true)
    }

    @Test
    func stagedFileAppearsAsIndexNew() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }
        try "hello".write(to: directory.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try repository.add(path: "a.txt").get()

        let entries = try repository.status().get()

        #expect(entries.first?.status.contains(.indexNew) == true)
    }

    @Test
    func commitRecordsMessageAndAuthor() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        let commit = try commitFile(
            named: "a.txt",
            message: "feat: first",
            in: repository,
            directory: directory
        )

        #expect(commit.message.hasPrefix("feat: first"))
        #expect(commit.author.name == "Tester")
        #expect(commit.author.email == "tester@example.com")
        #expect(commit.parents.isEmpty)
        #expect(try repository.status().get().isEmpty)
    }

    @Test
    func secondCommitHasFirstAsParent() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = try commitFile(named: "a.txt", in: repository, directory: directory)
        let second = try commitFile(named: "b.txt", in: repository, directory: directory)

        #expect(second.parents.map(\.oid) == [first.oid])
        #expect(try repository.commit(second.oid).get() == second)
    }

    @Test
    func headAndLocalBranchPointToLatestCommit() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }
        let commit = try commitFile(named: "a.txt", in: repository, directory: directory)

        let head = try repository.HEAD().get()
        let branches = try repository.localBranches().get()

        #expect(head.oid == commit.oid)
        #expect(branches.count == 1)
        #expect(branches.first?.oid == commit.oid)
        #expect(branches.first?.isLocal == true)
    }

    @Test
    func numberOfCommitsCountsHistory() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }
        _ = try commitFile(named: "a.txt", in: repository, directory: directory)
        _ = try commitFile(named: "b.txt", in: repository, directory: directory)
        let branch = try #require(try repository.localBranches().get().first)

        #expect(repository.numberOfCommits(in: branch) == 2)
    }

    @Test
    func diffListsAddedFile() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }
        let commit = try commitFile(named: "a.txt", in: repository, directory: directory)

        let diff = try repository.diff(for: commit).get()

        #expect(diff.deltas.map { $0.newFile?.path } == ["a.txt"])
    }

    @Test
    func missingRemoteFails() throws {
        let (repository, directory) = try makeRepository()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(throws: (any Error).self) { try repository.remote(named: "origin").get() }
        #expect(try repository.allRemotes().get().isEmpty)
    }
}
