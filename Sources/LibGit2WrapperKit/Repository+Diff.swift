import Foundation
import Libgit2Module

extension Repository {
    // MARK: - Diffs

    /// Perform a diff.
    public func diff(for commit: Commit) -> Result<Diff, NSError> {
        guard !commit.parents.isEmpty else {
            // Initial commit in a repository
            return diff(from: nil, to: commit.oid)
        }

        var mergeDiff: OpaquePointer?
        defer { git_object_free(mergeDiff) }
        for parent in commit.parents {
            let error = diff(from: parent.oid, to: commit.oid) {
                switch $0 {
                case let .failure(error):
                    return error

                case let .success(newDiff):
                    if mergeDiff == nil {
                        mergeDiff = newDiff
                    } else {
                        let mergeResult = git_diff_merge(mergeDiff, newDiff)
                        guard mergeResult == GIT_OK.rawValue else {
                            return NSError(gitError: mergeResult, pointOfFailure: "git_diff_merge")
                        }
                    }
                    return nil
                }
            }

            if error != nil {
                return Result<Diff, NSError>.failure(error!)
            }
        }

        return .success(Diff(mergeDiff!))
    }

    func diff(
        from oldCommitOid: OID?,
        to newCommitOid: OID?,
        transform: (Result<OpaquePointer, NSError>) -> NSError?
    ) -> NSError? {
        assert(
            oldCommitOid != nil || newCommitOid != nil,
            "It is an error to pass nil for both the oldOid and newOid"
        )

        var oldTree: OpaquePointer?
        defer { git_object_free(oldTree) }
        if let oid = oldCommitOid {
            switch unsafeTreeForCommitId(oid) {
            case let .failure(error):
                return transform(.failure(error))
            case let .success(value):
                oldTree = value
            }
        }

        var newTree: OpaquePointer?
        defer { git_object_free(newTree) }
        if let oid = newCommitOid {
            switch unsafeTreeForCommitId(oid) {
            case let .failure(error):
                return transform(.failure(error))
            case let .success(value):
                newTree = value
            }
        }

        var diff: OpaquePointer?
        let diffResult = git_diff_tree_to_tree(
            &diff,
            pointer,
            oldTree,
            newTree,
            nil
        )

        guard diffResult == GIT_OK.rawValue else {
            return transform(.failure(NSError(
                gitError: diffResult,
                pointOfFailure: "git_diff_tree_to_tree"
            )))
        }

        return transform(Result<OpaquePointer, NSError>.success(diff!))
    }

    /// Perform a diff.
    func diff( // swiftlint:disable:this function_body_length
        from oldCommitOid: OID?,
        to newCommitOid: OID?
    ) -> Result<Diff, NSError> {
        assert(
            oldCommitOid != nil || newCommitOid != nil,
            "It is an error to pass nil for both the oldOid and newOid"
        )

        var oldTree: Tree?
        if let oldCommitOid {
            switch safeTreeForCommitId(oldCommitOid) {
            case let .failure(error):
                return .failure(error)
            case let .success(value):
                oldTree = value
            }
        }

        var newTree: Tree?
        if let newCommitOid {
            switch safeTreeForCommitId(newCommitOid) {
            case let .failure(error):
                return .failure(error)
            case let .success(value):
                newTree = value
            }
        }

        if oldTree != nil, newTree != nil {
            return withGitObjects([oldTree!.oid, newTree!.oid], type: GIT_OBJECT_TREE) { objects in
                var diff: OpaquePointer?
                let diffResult = git_diff_tree_to_tree(
                    &diff,
                    self.pointer,
                    objects[0],
                    objects[1],
                    nil
                )
                return processTreeToTreeDiff(diffResult, diff: diff)
            }
        } else if let tree = oldTree {
            return withGitObject(tree.oid, type: GIT_OBJECT_TREE, transform: { tree in
                var diff: OpaquePointer?
                let diffResult = git_diff_tree_to_tree(
                    &diff,
                    self.pointer,
                    tree,
                    nil,
                    nil
                )
                return processTreeToTreeDiff(diffResult, diff: diff)
            })
        } else if let tree = newTree {
            return withGitObject(tree.oid, type: GIT_OBJECT_TREE, transform: { tree in
                var diff: OpaquePointer?
                let diffResult = git_diff_tree_to_tree(
                    &diff,
                    self.pointer,
                    nil,
                    tree,
                    nil
                )
                return processTreeToTreeDiff(diffResult, diff: diff)
            })
        }

        return .failure(NSError(gitError: -1, pointOfFailure: "diff(from: to:)"))
    }

    func processTreeToTreeDiff(_ diffResult: Int32, diff: OpaquePointer?) -> Result<Diff, NSError> {
        guard diffResult == GIT_OK.rawValue else {
            return .failure(NSError(
                gitError: diffResult,
                pointOfFailure: "git_diff_tree_to_tree"
            ))
        }

        let diffObj = Diff(diff!)
        git_diff_free(diff)
        return .success(diffObj)
    }

    func processDiffDeltas(_ diffResult: OpaquePointer) -> Result<[Diff.Delta], NSError> {
        var returnDict = [Diff.Delta]()

        let count = git_diff_num_deltas(diffResult)

        for i in 0 ..< count {
            let delta = git_diff_get_delta(diffResult, i)
            let gitDiffDelta = Diff.Delta((delta?.pointee)!)

            returnDict.append(gitDiffDelta)
        }

        return Result<[Diff.Delta], NSError>.success(returnDict)
    }

    func safeTreeForCommitId(_ oid: OID) -> Result<Tree, NSError> {
        withGitObject(oid, type: GIT_OBJECT_COMMIT) { commit in
            let treeId = git_commit_tree_id(commit)
            return tree(OID(treeId!.pointee))
        }
    }

    /// Caller responsible to free returned tree with git_object_free
    func unsafeTreeForCommitId(_ oid: OID) -> Result<OpaquePointer, NSError> {
        var commit: OpaquePointer?
        var oid = oid.oid
        let commitResult = git_object_lookup(&commit, pointer, &oid, GIT_OBJECT_COMMIT)
        guard commitResult == GIT_OK.rawValue else {
            return .failure(NSError(gitError: commitResult, pointOfFailure: "git_object_lookup"))
        }

        var tree: OpaquePointer?
        let treeId = git_commit_tree_id(commit)
        let treeResult = git_object_lookup(&tree, pointer, treeId, GIT_OBJECT_TREE)

        git_object_free(commit)

        guard treeResult == GIT_OK.rawValue else {
            return .failure(NSError(gitError: treeResult, pointOfFailure: "git_object_lookup"))
        }

        return Result<OpaquePointer, NSError>.success(tree!)
    }
}
