import Foundation
import Libgit2Module

extension Repository {
    // MARK: - Reference Lookups

    /// Load all the references with the given prefix (e.g. "refs/heads/")
    /// - Parameter prefix: The prefix of the branch
    /// - Returns: Return a `Result<[ReferenceType], NSError>`
    public func references(withPrefix prefix: String) -> Result<[ReferenceType], NSError> {
        let pointer = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
        let result = git_reference_list(pointer, self.pointer)

        guard result == GIT_OK.rawValue else {
            pointer.deallocate()
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_reference_list"))
        }

        let strarray = pointer.pointee
        let references = strarray
            .filter {
                $0.hasPrefix(prefix)
            }
            .map {
                self.reference(named: $0)
            }
        git_strarray_dispose(pointer)
        pointer.deallocate()

        return references.aggregateResult()
    }

    /// Load the reference with the given long name (e.g. "refs/heads/master")
    ///
    /// If the reference is a branch, a `Branch` will be returned. If the
    /// reference is a tag, a `TagReference` will be returned. Otherwise, a
    /// `Reference` will be returned.
    /// - Parameter name: The name of the reference
    /// - Returns: Return a `Result<ReferenceType, NSError>`
    public func reference(named name: String) -> Result<ReferenceType, NSError> {
        var pointer: OpaquePointer?
        let result = git_reference_lookup(&pointer, self.pointer, name)

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_reference_lookup"))
        }

        let value = referenceWithLibGit2Reference(pointer!)
        git_reference_free(pointer)
        return .success(value)
    }

    /// Load and return a list of all local branches.
    public func localBranches() -> Result<[Branch], NSError> {
        references(withPrefix: "refs/heads/")
            .map { (refs: [ReferenceType]) in
                refs.map { $0 as! Branch } // swiftlint:disable:this force_cast
            }
    }

    /// Load and return a list of all remote branches.
    public func remoteBranches() -> Result<[Branch], NSError> {
        references(withPrefix: "refs/remotes/")
            .map { (refs: [ReferenceType]) in
                refs.map { $0 as! Branch } // swiftlint:disable:this force_cast
            }
    }

    /// Load the local branch with the given name (e.g., "master").
    /// - Parameter name: The branch name
    /// - Returns: Return a `Result<Branch, NSError>`
    public func localBranch(named name: String) -> Result<Branch, NSError> {
        reference(named: "refs/heads/" + name)
            .map { $0 as! Branch } // swiftlint:disable:this force_cast
    }

    /// Load the remote branch with the given name (e.g., "origin/master").
    /// - Parameter name: The remote branch name
    /// - Returns: Return a `Result<Branch, NSError>`
    public func remoteBranch(named name: String) -> Result<Branch, NSError> {
        reference(named: "refs/remotes/" + name)
            .map { $0 as! Branch } // swiftlint:disable:this force_cast
    }

    /// Load and return a list of all the `TagReference`s.
    /// - Returns: Return a `Result<[TagReference], NSError>`
    public func allTags() -> Result<[TagReference], NSError> {
        references(withPrefix: "refs/tags/")
            .map { (refs: [ReferenceType]) in
                refs.map { $0 as! TagReference } // swiftlint:disable:this force_cast
            }
    }

    /// Load the tag with the given name (e.g., "tag-2").
    /// - Parameter name: The tag name
    /// - Returns: Return a `Result<TagReference, NSError>`
    public func tag(named name: String) -> Result<TagReference, NSError> {
        reference(named: "refs/tags/" + name)
            .map { $0 as! TagReference } // swiftlint:disable:this force_cast
    }
}
