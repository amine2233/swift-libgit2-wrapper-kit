import Foundation
import Libgit2Module

extension Repository {
    // MARK: - Commit

    /// Performs a commit of the staged files with the specified message and author
    public func commit( // swiftlint:disable:this function_parameter_count
        index _: OpaquePointer!,
        tree treeOid: git_oid,
        parents: [Commit],
        message: String,
        author: String,
        email: String
    ) -> Result<Commit, NSError> {
        // create commit signature
        var signature: UnsafeMutablePointer<git_signature>?
        let time = git_time_t(NSDate().timeIntervalSince1970) // Unix epoch time
        let offset: Int32 = 0
        let signatureResult = git_signature_new(&signature, author, email, time, offset)
        guard signatureResult == GIT_OK.rawValue else {
            let err = NSError(gitError: signatureResult, pointOfFailure: "git_signature_new")
            return .failure(err)
        }

        var tree: OpaquePointer?
        var treeOidVar = treeOid
        let lookupResult = git_tree_lookup(&tree, pointer, &treeOidVar)
        guard lookupResult == GIT_OK.rawValue else {
            let err = NSError(gitError: lookupResult, pointOfFailure: "git_tree_lookup")
            return .failure(err)
        }

        var msgBuf = git_buf()
        git_message_prettify(&msgBuf, message, 0, /* ascii for # */ 35)

        // use HEAD as parent
        var parentC: [OpaquePointer?] = []
        for parentCommit in parents {
            var parent: OpaquePointer?
            var oid = parentCommit.oid.oid
            git_commit_lookup(&parent, pointer, &oid)
            parentC.append(parent!)
        }

        let parentsContiguous = ContiguousArray(parentC)
        return parentsContiguous.withUnsafeBufferPointer { pointer in
            var commitOid = git_oid()
            let parentsPtr = UnsafeMutablePointer(mutating: pointer.baseAddress)
            let result = git_commit_create(
                &commitOid,
                self.pointer,
                "HEAD",
                signature,
                signature,
                nil,
                msgBuf.ptr,
                tree,
                parents.count,
                parentsPtr
            )

            git_buf_dispose(&msgBuf)
            git_signature_free(signature)
            git_tree_free(tree)

            guard result == GIT_OK.rawValue else {
                let err = NSError(gitError: result, pointOfFailure: "git_commit_create")
                return .failure(err)
            }

            return commit(OID(commitOid))
        }
    }

    /// The current tip as the single parent of a new commit, or no parent when HEAD is unborn.
    func headParents() -> Result<[Commit], NSError> {
        var parentID = git_oid()
        let result = git_reference_name_to_id(&parentID, pointer, "HEAD")
        if result == GIT_ENOTFOUND.rawValue {
            return .success([])
        }
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_reference_name_to_id"))
        }

        return commit(OID(parentID)).map { [$0] }
    }

    /// Performs a commit of the staged files with the specified message and author
    public func commit(message: String, author: String, email: String) -> Result<Commit, NSError> {
        unsafeIndex().flatMap { index in
            defer { git_index_free(index) }
            var treeOid = git_oid()
            let treeResult = git_index_write_tree(&treeOid, index)
            guard treeResult == GIT_OK.rawValue else {
                let err = NSError(gitError: treeResult, pointOfFailure: "git_index_write_tree")
                return .failure(err)
            }

            return headParents().flatMap { parents in
                commit(
                    index: index,
                    tree: treeOid,
                    parents: parents,
                    message: message,
                    author: author,
                    email: email
                )
            }
        }
    }

    /// Load all commits in the specified branch in topological & time order descending
    ///
    /// :param: branch The branch to get all commits from
    /// :returns: Returns a result with array of branches or the error that occurred
    public func commits(in branch: Branch) -> CommitIterator {
        CommitIterator(repo: self, root: branch.oid.oid)
    }

    /// Returns the number of commits reachable from the given branch.
    public func numberOfCommits(in branch: Branch) -> Int {
        var count = 0
        let commits = commits(in: branch)
        while commits.next() != nil {
            count += 1
        }
        return count
    }

    /// Get the index for the repo. The caller is responsible for freeing the index.
    func unsafeIndex() -> Result<OpaquePointer, NSError> {
        var index: OpaquePointer?
        let result = git_repository_index(&index, pointer)
        guard result == GIT_OK.rawValue, index != nil else {
            let err = NSError(gitError: result, pointOfFailure: "git_repository_index")
            return .failure(err)
        }

        return .success(index!)
    }

    /// Stage the file(s) under the specified path.
    public func add(path: String) -> Result<Void, NSError> {
        let dir = path
        var dirPointer = UnsafeMutablePointer<Int8>(mutating: (dir as NSString).utf8String)
        var paths = withUnsafeMutablePointer(to: &dirPointer) {
            git_strarray(strings: $0, count: 1)
        }
        return unsafeIndex().flatMap { index in
            defer { git_index_free(index) }

            // add this to print or log added files
            // let pointer = UnsafeMutablePointer<git_index_matched_path_cb>.allocate(capacity: 1)
            // var options = pointer.move()
            // pointer.deallocate()
            // options = printMatchedCBCallback

            // var repository = self

            let addResult = git_index_add_all(index, &paths, 0, nil, nil)
            guard addResult == GIT_OK.rawValue else {
                return .failure(NSError(gitError: addResult, pointOfFailure: "git_index_add_all"))
            }

            // write index to disk
            let writeResult = git_index_write(index)
            guard writeResult == GIT_OK.rawValue else {
                return .failure(NSError(gitError: writeResult, pointOfFailure: "git_index_write"))
            }

            return .success(())
        }
    }

    /// Perform a commit with arbitrary numbers of parent commits.
    public func commit( // swiftlint:disable:this function_body_length
        tree treeOID: OID,
        parents: [Commit],
        message: String,
        signature: Signature
    ) -> Result<Commit, NSError> {
        // create commit signature
        signature.makeUnsafeSignature().flatMap { signature in
            defer { git_signature_free(signature) }
            var tree: OpaquePointer?
            var treeOIDCopy = treeOID.oid
            let lookupResult = git_tree_lookup(&tree, self.pointer, &treeOIDCopy)
            guard lookupResult == GIT_OK.rawValue else {
                let err = NSError(gitError: lookupResult, pointOfFailure: "git_tree_lookup")
                return .failure(err)
            }

            defer { git_tree_free(tree) }

            var msgBuf = git_buf()
            git_message_prettify(&msgBuf, message, 0, /* ascii for # */ 35)
            defer { git_buf_dispose(&msgBuf) }

            // libgit2 expects a C-like array of parent git_commit pointer
            var parentGitCommits: [OpaquePointer?] = []
            defer {
                for commit in parentGitCommits {
                    git_commit_free(commit)
                }
            }
            for parentCommit in parents {
                var parent: OpaquePointer?
                var oid = parentCommit.oid.oid
                let lookupResult = git_commit_lookup(&parent, self.pointer, &oid)
                guard lookupResult == GIT_OK.rawValue else {
                    let err = NSError(gitError: lookupResult, pointOfFailure: "git_commit_lookup")
                    return .failure(err)
                }

                parentGitCommits.append(parent!)
            }

            let parentsContiguous = ContiguousArray(parentGitCommits)
            return parentsContiguous.withUnsafeBufferPointer { unsafeBuffer in
                var commitOID = git_oid()
                let parentsPtr = UnsafeMutablePointer(mutating: unsafeBuffer.baseAddress)
                let result = git_commit_create(
                    &commitOID,
                    self.pointer,
                    "HEAD",
                    signature,
                    signature,
                    "UTF-8",
                    msgBuf.ptr,
                    tree,
                    parents.count,
                    parentsPtr
                )
                guard result == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: result, pointOfFailure: "git_commit_create"))
                }

                return commit(OID(commitOID))
            }
        }
    }

    /// Perform a commit of the staged files with the specified message and signature,
    /// assuming we are not doing a merge and using the current tip as the parent.
    public func commit(message: String, signature: Signature) -> Result<Commit, NSError> {
        unsafeIndex().flatMap { index in
            defer { git_index_free(index) }
            var treeOID = git_oid()
            let treeResult = git_index_write_tree(&treeOID, index)
            guard treeResult == GIT_OK.rawValue else {
                let err = NSError(gitError: treeResult, pointOfFailure: "git_index_write_tree")
                return .failure(err)
            }

            return headParents().flatMap { parents in
                commit(tree: OID(treeOID), parents: parents, message: message, signature: signature)
            }
        }
    }
}
