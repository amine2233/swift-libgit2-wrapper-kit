import Foundation
import Libgit2Module

/// A git branch.
public struct Branch: ReferenceType, Hashable {
    /// The full name of the reference (e.g., `refs/heads/master`).
    public let longName: String

    /// The short human-readable name of the branch (e.g., `master`).
    public let name: String

    /// A pointer to the referenced commit.
    public let commit: PointerTo<Commit>

    // MARK: Derived Properties

    /// The short human-readable name of the branch (e.g., `master`).
    ///
    /// This is the same as `name`, but is declared with an Optional type to adhere to
    /// `ReferenceType`.
    public var shortName: String? {
        name
    }

    /// The OID of the referenced object.
    ///
    /// This is the same as `commit.oid`, but is declared here to adhere to `ReferenceType`.
    public var oid: OID {
        commit.oid
    }

    /// Whether the branch is a local branch.
    public var isLocal: Bool {
        longName.hasPrefix("refs/heads/")
    }

    /// Whether the branch is a remote branch.
    public var isRemote: Bool {
        longName.hasPrefix("refs/remotes/")
    }

    /// Create an instance with a libgit2 `git_reference` object.
    ///
    /// Returns `nil` if the pointer isn't a branch.
    public init?(_ pointer: OpaquePointer) {
        var namePointer: UnsafePointer<Int8>?
        let success = git_branch_name(&namePointer, pointer)
        guard success == GIT_OK.rawValue else {
            return nil
        }

        self.name = String(validatingCString: namePointer!)!

        self.longName = String(validatingCString: git_reference_name(pointer))!

        var oid: OID
        if git_reference_type(pointer).rawValue == GIT_REFERENCE_SYMBOLIC.rawValue {
            var resolved: OpaquePointer?
            let success = git_reference_resolve(&resolved, pointer)
            guard success == GIT_OK.rawValue else {
                return nil
            }

            oid = OID(git_reference_target(resolved).pointee)
            git_reference_free(resolved)
        } else {
            oid = OID(git_reference_target(pointer).pointee)
        }
        self.commit = PointerTo<Commit>(oid)
    }

    /// Get tracked branch
    /// - Parameter repo: The repository
    /// - Returns: the Result with `Branch` or with failure
    public func getTrackingBranch(repo: Repository) -> Result<Branch, NSError> {
        if isRemote {
            return .success(self)
        }
        var branchReference: OpaquePointer?
        var trackingReference: OpaquePointer?
        return longName.withCString { branchName in
            let lookupResult = git_reference_lookup(&branchReference, repo.pointer, branchName)
            guard lookupResult == GIT_OK.rawValue else {
                return .failure(NSError(gitError: lookupResult, pointOfFailure: "git_reference_lookup"))
            }

            defer { git_reference_free(branchReference) }
            let upstreamResult = git_branch_upstream(&trackingReference, branchReference)
            guard upstreamResult == GIT_OK.rawValue else {
                return .failure(NSError(
                    gitError: upstreamResult,
                    pointOfFailure: "git_branch_upstream",
                    suggestionsFix: [
                        "Inside the repository run this commands",
                        "git config --local --add branch.main.merge \(longName)",
                        "git config --local --add branch.main.remote origin",
                        "Then re-run your action"
                    ]
                ))
            }
            guard let trackingReference else {
                return .failure(NSError(
                    gitError: upstreamResult,
                    pointOfFailure: "dereference trackingReference"
                ))
            }
            guard let branch = Branch(trackingReference) else {
                return .failure(NSError(
                    gitError: upstreamResult,
                    pointOfFailure: "creating Branch from trackingReference"
                ))
            }

            return .success(branch)
        }
    }
}
