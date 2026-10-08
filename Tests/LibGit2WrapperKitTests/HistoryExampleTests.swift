import Foundation
import Testing
@testable import LibGit2WrapperKit

struct HistoryExampleTests {
    struct HistoryEntry {
        let id: OID
        let summary: String
        let author: String
        let date: Date
        let changedFiles: [String]
    }

    private func fullHistory(of repository: Repository) throws -> [HistoryEntry] {
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

    @Test
    func historyListsEveryCommitOnceWithItsChangedFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2WrapperKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try Repository.create(at: directory).get()
        for name in ["a.txt", "b.txt"] {
            try name.write(to: directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
            try repository.add(path: name).get()
            _ = try repository.commit(
                message: "feat: add \(name)\n\nbody",
                author: "Tester",
                email: "t@example.com"
            ).get()
        }

        let history = try fullHistory(of: repository)

        #expect(history.count == 2)
        #expect(Set(history.map(\.summary)) == ["feat: add a.txt", "feat: add b.txt"])
        #expect(history.map(\.changedFiles).sorted { $0[0] < $1[0] } == [["a.txt"], ["b.txt"]])
        #expect(history.allSatisfy { $0.author == "Tester" })
    }
}
