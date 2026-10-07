import Foundation
import Libgit2Module

extension Repository {
    // MARK: - Working Directory

    /// Load the reference pointed at by HEAD.
    ///
    /// When on a branch, this will return the current `Branch`.
    /// - Returns: Return a `Result<ReferenceType, NSError>`
    public func HEAD() -> Result<ReferenceType, NSError> {
        var pointer: OpaquePointer?
        let result = git_repository_head(&pointer, self.pointer)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_head"))
        }

        let value = referenceWithLibGit2Reference(pointer!)
        git_reference_free(pointer)
        return Result.success(value)
    }

    /// Set HEAD to the given oid (detached).
    ///
    /// :param: oid The OID to set as HEAD.
    /// :returns: Returns a result with void or the error that occurred.
    /// - Parameter oid: The id of the commit
    /// - Returns: Return a `Result<Void, NSError>`
    public func setHEAD(_ oid: OID) -> Result<Void, NSError> {
        var oid = oid.oid
        let result = git_repository_set_head_detached(pointer, &oid)
        guard result == GIT_OK.rawValue else {
            return Result
                .failure(NSError(gitError: result, pointOfFailure: "git_repository_set_head_detached"))
        }

        return Result.success(())
    }

    /// Set HEAD to the given reference.
    ///
    /// :param: reference The reference to set as HEAD.
    /// :returns: Returns a result with void or the error that occurred.
    public func setHEAD(_ reference: ReferenceType) -> Result<Void, NSError> {
        let result = git_repository_set_head(pointer, reference.longName)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_set_head"))
        }

        return Result.success(())
    }

    // MARK: - Checkout

    /// Check out HEAD.
    ///
    /// :param: strategy The checkout strategy to use.
    /// :param: progress A block that's called with the progress of the checkout.
    /// :returns: Returns a result with void or the error that occurred.
    public func checkout(
        strategy: CheckoutStrategy,
        progress: CheckoutProgressBlock? = nil
    ) -> Result<Void, NSError> {
        var options = checkoutOptions(strategy: strategy, progress: progress)

        let result = git_checkout_head(pointer, &options)
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_checkout_head"))
        }

        return Result.success(())
    }

    /// Check out the given OID.
    ///
    /// :param: oid The OID of the commit to check out.
    /// :param: strategy The checkout strategy to use.
    /// :param: progress A block that's called with the progress of the checkout.
    /// :returns: Returns a result with void or the error that occurred.
    public func checkout(
        _ oid: OID,
        strategy: CheckoutStrategy,
        progress: CheckoutProgressBlock? = nil
    ) -> Result<Void, NSError> {
        setHEAD(oid).flatMap { self.checkout(strategy: strategy, progress: progress) }
    }

    /// Check out the given reference.
    ///
    /// :param: reference The reference to check out.
    /// :param: strategy The checkout strategy to use.
    /// :param: progress A block that's called with the progress of the checkout.
    /// :returns: Returns a result with void or the error that occurred.
    public func checkout(
        _ reference: ReferenceType,
        strategy: CheckoutStrategy,
        progress: CheckoutProgressBlock? = nil
    ) -> Result<Void, NSError> {
        setHEAD(reference).flatMap { self.checkout(strategy: strategy, progress: progress) }
    }

    /// How far a reset moves back, mirroring `git reset --soft|--mixed|--hard`.
    public enum ResetType {
        /// Move the branch only; keep the index and working tree.
        case soft
        /// Move the branch and reset the index; keep the working tree.
        case mixed
        /// Move the branch and reset the index and working tree, discarding every local change.
        case hard

        fileprivate var gitValue: git_reset_t {
            switch self {
            case .soft: GIT_RESET_SOFT
            case .mixed: GIT_RESET_MIXED
            case .hard: GIT_RESET_HARD
            }
        }
    }

    /// Move the current branch to `commit`, for example to discard local commits that were never pushed.
    /// - Parameters:
    ///   - commit: The commit the current branch should point to.
    ///   - type: How much state to reset. Defaults to ``ResetType/hard``.
    /// - Returns: Return a `Result<Void, NSError>`
    public func reset(to commit: Commit, type: ResetType = .hard) -> Result<Void, NSError> {
        var object: OpaquePointer?
        var oid = commit.oid.oid
        let lookupResult = git_object_lookup(&object, pointer, &oid, GIT_OBJECT_COMMIT)
        guard lookupResult == GIT_OK.rawValue else {
            return .failure(NSError(gitError: lookupResult, pointOfFailure: "git_object_lookup"))
        }

        defer { git_object_free(object) }

        var options = checkoutOptions(strategy: .Force)
        let result = git_reset(pointer, object, type.gitValue, &options)
        guard result == GIT_OK.rawValue else {
            return .failure(NSError(gitError: result, pointOfFailure: "git_reset"))
        }

        return .success(())
    }

    /// checkout to the given branch
    /// - Parameter branch: The branch
    /// - Returns: Returns a result with void or the error that occurred.
    public func checkout(_ branch: Branch) -> Result<Void, NSError> {
        let branchName = branch.longName
        let result = branchName.withCString {
            git_repository_set_head(pointer, $0)
        }
        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_set_head"))
        }

        return Result.success(())
    }
}
