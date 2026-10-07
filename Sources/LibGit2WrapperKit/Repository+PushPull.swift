import Foundation
import Libgit2Module

extension Repository {
    // MARK: - Pushing / Pulling

    // swiftlint:disable function_body_length

    /// Push branch to the specified remote.
    /// This method not use proxy needed to push like on push2
    /// If branch is a local branch, will try to push to the corresponding remote branch with the same name.
    /// - Parameters:
    ///   - remote: The remote git repository
    ///   - branch: The git branch
    ///   - credentials: The git credential
    /// - Returns: Return a `Result<Void, NSError>`
    public func push(
        remote: Remote, branch: Branch,
        credentials: Credentials? = nil
    ) -> Result<Void, NSError> {
        remoteLookup(named: remote.name) { result in
            result.flatMap { remote in
                let connectResult: Int32
                if let credentials {
                    var callbacks = git_remote_callbacks()
                    let initCallbacksResult = git_remote_init_callbacks(
                        &callbacks,
                        UInt32(GIT_REMOTE_CALLBACKS_VERSION)
                    )
                    guard initCallbacksResult == GIT_OK.rawValue else {
                        print(errorMessage(initCallbacksResult)!)
                        return Result
                            .failure(NSError(
                                gitError: initCallbacksResult,
                                pointOfFailure: "git_remote_init_callbacks"
                            ))
                    }

                    callbacks.payload = credentials.toPointer()
                    callbacks.credentials = credentialsCallback

                    connectResult = git_remote_connect(remote, GIT_DIRECTION_PUSH, &callbacks, nil, nil)
                } else {
                    connectResult = git_remote_connect(remote, GIT_DIRECTION_PUSH, nil, nil, nil)
                }
                guard connectResult == GIT_OK.rawValue else {
                    return Result
                        .failure(NSError(gitError: connectResult, pointOfFailure: "git_remote_connect"))
                }

                var options: git_push_options
                if let credentials {
                    options = pushOptions(credentials: credentials)
                } else {
                    options = git_push_options()
                    git_push_options_init(&options, UInt32(GIT_PUSH_OPTIONS_VERSION))
                }
                // lookup refspec
                var refspecArray = git_strarray()
                let getRefspecsResult = git_remote_get_push_refspecs(&refspecArray, remote)
                guard getRefspecsResult == GIT_OK.rawValue else {
                    return Result
                        .failure(NSError(
                            gitError: getRefspecsResult,
                            pointOfFailure: "git_remote_get_push_refspecs"
                        ))
                }

                defer { git_strarray_dispose(&refspecArray) }
                let branchRefspec = "\(branch.longName):\(branch.longName)"
                let refspec = refspecArray.filter { $0 == branchRefspec }.first ?? branchRefspec

                let ptrRefspec = strdup(refspec)
                defer { free(ptrRefspec) }
                var selectedRefspecs = [ptrRefspec]
                var selectedRefspecArray = selectedRefspecs.withUnsafeMutableBufferPointer { buffer in
                    git_strarray(strings: buffer.baseAddress, count: 1)
                }
                // do the push
                let uploadResult = git_remote_upload(remote, &selectedRefspecArray, &options)
                guard uploadResult == GIT_OK.rawValue else {
                    return Result
                        .failure(NSError(gitError: uploadResult, pointOfFailure: "git_remote_upload"))
                }

                return .success(())
            }
        }
    }

    // swiftlint:enable function_body_length

    // swiftlint:disable function_body_length

    /// Push change to the remote server version two
    /// - Parameters:
    ///   - remote: The git remote
    ///   - branch: The git branch
    ///   - credentials: The git credentials
    ///   - proxy: The git proxy
    /// - Returns: Return a `Result<Void, NSError>`
    public func push2(
        remote: Remote,
        branch: Branch,
        credentials: Credentials? = nil,
        proxy: ProxyConfiguration? = nil
    ) -> Result<Void, NSError> {
        remoteLookup(named: remote.name) { result in
            result.flatMap { remote in
                let connectResult: Int32
                let proxyOpts = UnsafeMutablePointer<git_proxy_options>.allocate(capacity: 1)
                defer { proxyOpts.deallocate() }
                proxyOpts.pointee = proxyOptions(proxy: proxy)
                if let credentials {
                    var callbacks = git_remote_callbacks()
                    let initCallbacksResult = git_remote_init_callbacks(
                        &callbacks,
                        UInt32(GIT_REMOTE_CALLBACKS_VERSION)
                    )
                    guard initCallbacksResult == GIT_OK.rawValue else {
                        print(errorMessage(initCallbacksResult)!)
                        return Result
                            .failure(NSError(
                                gitError: initCallbacksResult,
                                pointOfFailure: "git_remote_init_callbacks"
                            ))
                    }

                    callbacks.payload = credentials.toPointer()
                    callbacks.credentials = credentialsCallback

                    connectResult = git_remote_connect(
                        remote,
                        GIT_DIRECTION_PUSH,
                        &callbacks,
                        proxyOpts,
                        nil
                    )
                } else {
                    connectResult = git_remote_connect(remote, GIT_DIRECTION_PUSH, nil, proxyOpts, nil)
                }
                guard connectResult == GIT_OK.rawValue else {
                    return Result
                        .failure(NSError(gitError: connectResult, pointOfFailure: "git_remote_connect"))
                }

                var options: git_push_options
                if let credentials {
                    options = pushOptions(credentials: credentials, proxy: proxy)
                } else {
                    options = git_push_options()
                    git_push_options_init(&options, UInt32(GIT_PUSH_OPTIONS_VERSION))
                }
                // lookup refspec
                let ptrRefspec = strdup(branch.longName)
                defer { free(ptrRefspec) }
                var selectedRefspecs = [ptrRefspec]
                var selectedRefspecArray = selectedRefspecs.withUnsafeMutableBufferPointer { buffer in
                    git_strarray(strings: buffer.baseAddress, count: 1)
                }
                // do the push
                let uploadResult = git_remote_push(remote, &selectedRefspecArray, &options)
                guard uploadResult == GIT_OK.rawValue else {
                    return Result
                        .failure(NSError(gitError: uploadResult, pointOfFailure: "git_remote_upload"))
                }

                return .success(())
            }
        }
    }

    // swiftlint:enable function_body_length

    /// The Git conflict decision
    public enum ConflictResolutionDecision: Sendable {
        /// Keep our version of the conflicted file.
        case ours
        /// Keep their version of the conflicted file.
        case theirs
        /// Use the provided data as the resolved content.
        case merge(Data)
    }

    /// Takes in "our" side and "their" side of the file respectively, and returns a decision
    public typealias ConflictResolver = (Data, Data) -> ConflictResolutionDecision

    // swiftlint:disable cyclomatic_complexity function_body_length function_parameter_count

    /// Pulls from the remote and updates our local branch.
    /// inspired by https://github.com/SwiftGit2/SwiftGit2/pull/125/files
    /// - Parameters:
    ///   - remote: The git remote
    ///   - branch: The git branch
    ///   - author: The git author
    ///   - email: The git email
    ///   - credentials: The git credentials
    ///   - proxy: The proxy infirmation
    ///   - conflictResolver: The conflict resolver
    /// - Returns: Result<Void, NSError>
    public func pull(
        remote: Remote,
        branch: Branch,
        author: String,
        email: String,
        credentials: Credentials = .default,
        proxy: ProxyConfiguration?,
        conflictResolver _: ConflictResolver
    ) -> Result<Void, NSError> {
        // first initiate a fetch
        fetch(remote, credentials: credentials, proxy: proxy).flatMap { _ in
            let localBranchResult = self.localBranch(named: branch.name)
            guard case let .success(localBranch) = localBranchResult else {
                return localBranchResult.map { _ in () }
            }

            // determine if we need to perform a merge
            // if local commit is the same as remote commit, no need
            return branch.getTrackingBranch(repo: self).flatMap { trackingBranch in
                // determine if the local branch can be fast-forwarded
                guard localBranch.oid != trackingBranch.oid else {
                    return .success(())
                }

                // determine if a clean merge can be performed
                var annotatedCommit: OpaquePointer?
                var oid = trackingBranch.oid.oid
                let lookupResult = git_annotated_commit_lookup(&annotatedCommit, self.pointer, &oid)
                guard lookupResult == GIT_OK.rawValue else {
                    return Result
                        .failure(NSError(
                            gitError: lookupResult,
                            pointOfFailure: "git_annotated_commit_lookup"
                        ))
                }

                defer { git_annotated_commit_free(annotatedCommit) }
                var analysis = GIT_MERGE_ANALYSIS_NONE
                var preference = GIT_MERGE_PREFERENCE_NONE
                let analysisResult = git_merge_analysis(
                    &analysis,
                    &preference,
                    self.pointer,
                    &annotatedCommit,
                    1
                )
                guard analysisResult == GIT_OK.rawValue else {
                    return Result
                        .failure(NSError(gitError: analysisResult, pointOfFailure: "git_merge_analysis"))
                }

                if analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue != 0 {
                    // nothing needs to be done
                    return .success(())
                } else if analysis.rawValue & GIT_MERGE_ANALYSIS_UNBORN.rawValue != 0
                    || analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue != 0 {
                    // fast-forward local branch
                    let message = "merge \(remote.name)/\(trackingBranch.name): Fast-forward"
                    return localBranch.referenceByUpdatingTarget(
                        repo: self,
                        newTarget: trackingBranch.oid,
                        message: message
                    ).flatMap { newRef in
                        self.checkout(newRef.oid, strategy: CheckoutStrategy.Force)
                    }
                } else if analysis.rawValue & GIT_MERGE_ANALYSIS_NORMAL.rawValue != 0 {
                    // normal merge
                    return unsafeTreeForCommitId(localBranch.commit.oid).flatMap { localTree in
                        defer { git_tree_free(localTree) }
                        return unsafeTreeForCommitId(trackingBranch.commit.oid).flatMap { remoteTree in
                            defer { git_tree_free(remoteTree) }
                            var baseTreePointer: OpaquePointer?
                            defer { git_tree_free(baseTreePointer) }
                            // check conflicts
                            var index: OpaquePointer?
                            var baseOid = git_oid()
                            var localOid = localBranch.commit.oid.oid
                            var remoteOid = trackingBranch.commit.oid.oid
                            let findMergeBaseResult = git_merge_base(
                                &baseOid,
                                self.pointer,
                                &localOid,
                                &remoteOid
                            )
                            if findMergeBaseResult == GIT_OK.rawValue {
                                let result = commit(OID(baseOid))
                                    .flatMap { baseCommit -> Result<Void, NSError> in
                                        unsafeTreeForCommitId(baseCommit.oid)
                                            .flatMap { baseTree -> Result<Void, NSError> in
                                                baseTreePointer = baseTree
                                                return .success(())
                                            }
                                    }
                                if case .failure = result {
                                    return result
                                }
                            }
                            let mergeTreeResult = git_merge_trees(
                                &index,
                                self.pointer,
                                baseTreePointer,
                                localTree,
                                remoteTree,
                                nil
                            )
                            guard mergeTreeResult == GIT_OK.rawValue else {
                                return Result
                                    .failure(NSError(
                                        gitError: mergeTreeResult,
                                        pointOfFailure: "git_merge_trees"
                                    ))
                            }

                            // if a clean merge cannot be performed,
                            // call the user-supplied conflict resolver
                            if git_index_has_conflicts(index!) > 0 {
                                fatalError()
                            }
                            var treeOid = git_oid()
                            let writeTreeResult = git_index_write_tree_to(&treeOid, index!, self.pointer)
                            guard writeTreeResult == GIT_OK.rawValue else {
                                return Result
                                    .failure(NSError(
                                        gitError: writeTreeResult,
                                        pointOfFailure: "git_index_write_tree"
                                    ))
                            }

                            // create merge commit
                            var parents: [Commit] = []
                            for commitMerge in [
                                commit(localBranch.commit.oid),
                                commit(trackingBranch.commit.oid)
                            ] {
                                if case .failure = commitMerge {
                                    return commitMerge.map { _ in () }
                                } else if case let .success(commit) = commitMerge {
                                    parents.append(commit)
                                }
                            }
                            let message = "Merge branch '\(localBranch.shortName ?? localBranch.name)'"
                            return commit(
                                index: index,
                                tree: treeOid,
                                parents: parents,
                                message: message,
                                author: author,
                                email: email
                            ).flatMap { commit in
                                checkout(commit.oid, strategy: CheckoutStrategy.Force)
                            }
                        }
                    }
                } else {
                    return Result
                        .failure(NSError(gitError: analysisResult, pointOfFailure: "decoding merge result"))
                }
            }
        }
    }

    // swiftlint:enable cyclomatic_complexity function_body_length function_parameter_count

    /// Pulls from the remote and updates our local branch.
    /// https://github.com/SwiftGit2/SwiftGit2/pull/129/files
    /// - Parameters:
    ///   - remote: The git remote
    ///   - branch: The git branch
    ///   - signatureMaker: The git signature
    ///   - credentials: The git credentials
    ///   - proxy: the proxy information
    ///   - _: The git conflict resolver
    ///   - progress: The git progress
    /// - Returns: return a `Result<Void, NSError>`
    public func pull2( // swiftlint:disable:this function_body_length cyclomatic_complexity
        remote: Remote,
        branch: Branch,
        signatureMaker: () -> Signature,
        credentials: Credentials = .default,
        proxy: ProxyConfiguration?,
        conflictResolver _: ConflictResolver,
        progress: CheckoutProgressBlock? = nil
    ) -> Result<Void, NSError> {
        // first initiate a fetch
        fetch(remote, credentials: credentials, proxy: proxy).flatMap { _ in
            let localBranchResult = self.localBranch(named: branch.name)
            guard case let .success(localBranch) = localBranchResult else {
                return localBranchResult.map { _ in () }
            }

            // determine if we need to perform a merge
            // if local commit is the same as remote commit, no need
            return branch.getTrackingBranch(repo: self).flatMap { trackingBranch in
                // determine if the local branch can be fast-forwarded
                guard localBranch.oid != trackingBranch.oid else {
                    return .success(())
                }

                // determine if a clean merge can be performed
                var annotatedCommit: OpaquePointer?
                var oid = trackingBranch.oid.oid
                let lookupResult = git_annotated_commit_lookup(&annotatedCommit, self.pointer, &oid)
                guard lookupResult == GIT_OK.rawValue else {
                    return Result
                        .failure(NSError(
                            gitError: lookupResult,
                            pointOfFailure: "git_annotated_commit_lookup"
                        ))
                }

                defer { git_annotated_commit_free(annotatedCommit) }
                var analysis = GIT_MERGE_ANALYSIS_NONE
                var preference = GIT_MERGE_PREFERENCE_NONE
                let analysisResult = git_merge_analysis(
                    &analysis,
                    &preference,
                    self.pointer,
                    &annotatedCommit,
                    1
                )
                guard analysisResult == GIT_OK.rawValue else {
                    return Result
                        .failure(NSError(gitError: analysisResult, pointOfFailure: "git_merge_analysis"))
                }

                if analysis.rawValue & GIT_MERGE_ANALYSIS_UP_TO_DATE.rawValue != 0 {
                    // nothing needs to be done
                    return .success(())
                } else if analysis.rawValue & GIT_MERGE_ANALYSIS_UNBORN.rawValue != 0
                    || analysis.rawValue & GIT_MERGE_ANALYSIS_FASTFORWARD.rawValue != 0 {
                    // fast-forward local branch
                    let message = "merge \(remote.name)/\(trackingBranch.name): Fast-forward"
                    return localBranch.referenceByUpdatingTarget(
                        repo: self,
                        newTarget: trackingBranch.oid,
                        message: message
                    ).flatMap { newRef in
                        self.checkout(newRef.oid, strategy: CheckoutStrategy.Force, progress: progress)
                    }
                } else if analysis.rawValue & GIT_MERGE_ANALYSIS_NORMAL.rawValue != 0 {
                    // normal merge
                    return unsafeTreeForCommitId(localBranch.commit.oid).flatMap { localTree in
                        defer { git_tree_free(localTree) }
                        return unsafeTreeForCommitId(trackingBranch.commit.oid).flatMap { remoteTree in
                            defer { git_tree_free(remoteTree) }
                            // check conflicts
                            var index: OpaquePointer?
                            var baseOID = git_oid()
                            var localOID = localBranch.commit.oid.oid
                            var remoteOID = trackingBranch.commit.oid.oid
                            let findMergeBaseResult = git_merge_base(
                                &baseOID,
                                self.pointer,
                                &localOID,
                                &remoteOID
                            )
                            var baseTree: OpaquePointer?
                            if findMergeBaseResult == GIT_OK.rawValue {
                                let result = commit(OID(baseOID))
                                    .flatMap { baseCommit -> Result<Void, NSError> in
                                        unsafeTreeForCommitId(baseCommit.oid)
                                            .flatMap { baseTreeUnsafe -> Result<Void, NSError> in
                                                baseTree = baseTreeUnsafe
                                                return .success(())
                                            }
                                    }
                                if case .failure = result {
                                    return result
                                }
                            }
                            let mergeTreeResult = git_merge_trees(
                                &index,
                                self.pointer,
                                baseTree,
                                localTree,
                                remoteTree,
                                nil
                            )
                            guard mergeTreeResult == GIT_OK.rawValue else {
                                return Result
                                    .failure(NSError(
                                        gitError: mergeTreeResult,
                                        pointOfFailure: "git_merge_trees"
                                    ))
                            }

                            // if a clean merge cannot be performed,
                            // call the user-supplied conflict resolver
                            if git_index_has_conflicts(index!) > 0 {
                                fatalError()
                            }
                            var treeOID = git_oid()
                            let writeTreeResult = git_index_write_tree_to(&treeOID, index!, self.pointer)
                            guard writeTreeResult == GIT_OK.rawValue else {
                                return Result
                                    .failure(NSError(
                                        gitError: writeTreeResult,
                                        pointOfFailure: "git_index_write_tree"
                                    ))
                            }

                            // create merge commit
                            var parents: [Commit] = []
                            for parent in [
                                commit(localBranch.commit.oid),
                                commit(trackingBranch.commit.oid)
                            ] {
                                if case .failure = parent {
                                    return parent.map { _ in () }
                                } else if case let .success(commit) = parent {
                                    parents.append(commit)
                                }
                            }
                            let message = "Merge branch '\(localBranch.shortName ?? localBranch.name)'"
                            git_tree_free(baseTree)
                            return commit(
                                tree: OID(treeOID),
                                parents: parents,
                                message: message,
                                signature: signatureMaker()
                            ).flatMap { commit in
                                checkout(commit.oid, strategy: CheckoutStrategy.Force, progress: progress)
                            }
                        }
                    }
                } else {
                    return Result
                        .failure(NSError(gitError: analysisResult, pointOfFailure: "decoding merge result"))
                }
            }
        }
    }
}
