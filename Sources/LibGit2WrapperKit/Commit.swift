import Foundation
import Libgit2Module

/// A git commit.
public struct Commit: ObjectType, Hashable {
    public static let type = GIT_OBJECT_COMMIT

    /// The OID of the commit.
    public let oid: OID

    /// The OID of the commit's tree.
    public let tree: PointerTo<Tree>

    /// The OIDs of the commit's parents.
    public let parents: [PointerTo<Commit>]

    /// The author of the commit.
    public let author: Signature

    /// The committer of the commit.
    public let committer: Signature

    /// The full message of the commit.
    public let message: String

    /// Create an instance with a libgit2 `git_commit` object.
    public init(_ pointer: OpaquePointer) {
        self.oid = OID(git_object_id(pointer).pointee)
        self.message = String(validatingUTF8: git_commit_message(pointer))!
        self.author = Signature(git_commit_author(pointer).pointee)
        self.committer = Signature(git_commit_committer(pointer).pointee)
        self.tree = PointerTo(OID(git_commit_tree_id(pointer).pointee))

        self.parents = (0 ..< git_commit_parentcount(pointer)).map {
            PointerTo(OID(git_commit_parent_id(pointer, $0).pointee))
        }
    }
}
