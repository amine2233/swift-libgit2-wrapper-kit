import Foundation
import Libgit2Module

/// A reference to a git object.
public protocol ReferenceType {
    /// The full name of the reference (e.g., `refs/heads/master`).
    var longName: String { get }

    /// The short human-readable name of the reference if one exists (e.g., `master`).
    var shortName: String? { get }

    /// The OID of the referenced object.
    var oid: OID { get }

    /// Updates the on-disk reference to point to the target and returns the updated reference.
    func referenceByUpdatingTarget(repo: Repository, newTarget: OID, message: String)
        -> Result<ReferenceType, NSError>
}

extension ReferenceType {
    public func referenceByUpdatingTarget(
        repo: Repository,
        newTarget: OID,
        message: String
    ) -> Result<ReferenceType, NSError> {
        message.withCString { messageCString in
            self.longName.withCString { refName in
                var reference: OpaquePointer?
                let lookupResult = git_reference_lookup(&reference, repo.pointer, refName)
                guard lookupResult == GIT_OK.rawValue else {
                    return .failure(NSError(gitError: lookupResult, pointOfFailure: "git_reference_lookup"))
                }

                defer { git_reference_free(reference!) }
                var newRef: OpaquePointer?
                var oid = newTarget.oid
                let setTargetResult = git_reference_set_target(&newRef, reference!, &oid, messageCString)
                guard setTargetResult == GIT_OK.rawValue else {
                    return .failure(NSError(
                        gitError: setTargetResult,
                        pointOfFailure: "git_reference_set_target"
                    ))
                }

                return .success(Reference(newRef!))
            }
        }
    }
}

extension ReferenceType {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.longName == rhs.longName
            && lhs.oid == rhs.oid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(longName)
        hasher.combine(oid)
    }
}

/// Create a Reference, Branch, or TagReference from a libgit2 `git_reference`.
func referenceWithLibGit2Reference(_ pointer: OpaquePointer) -> ReferenceType {
    if git_reference_is_branch(pointer) != 0 || git_reference_is_remote(pointer) != 0 {
        Branch(pointer)!
    } else if git_reference_is_tag(pointer) != 0 {
        TagReference(pointer)!
    } else {
        Reference(pointer)
    }
}

/// A generic reference to a git object.
public struct Reference: ReferenceType, Hashable {
    /// The full name of the reference (e.g., `refs/heads/master`).
    public let longName: String

    /// The short human-readable name of the reference if one exists (e.g., `master`).
    public let shortName: String?

    /// The OID of the referenced object.
    public let oid: OID

    /// Create an instance with a libgit2 `git_reference` object.
    public init(_ pointer: OpaquePointer) {
        let shorthand = String(validatingCString: git_reference_shorthand(pointer))!
        self.longName = String(validatingCString: git_reference_name(pointer))!
        self.shortName = (shorthand == longName ? nil : shorthand)
        self.oid = OID(git_reference_target(pointer).pointee)
    }
}
