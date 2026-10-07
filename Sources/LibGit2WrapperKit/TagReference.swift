import Foundation
import Libgit2Module

/// A git tag reference, which can be either a lightweight tag or a Tag object.
public enum TagReference: ReferenceType, Hashable {
    /// A lightweight tag, which is just a name and an OID.
    case lightweight(String, OID)

    /// An annotated tag, which points to a Tag object.
    case annotated(String, Tag)

    /// The full name of the reference (e.g., `refs/tags/my-tag`).
    public var longName: String {
        switch self {
        case let .lightweight(name, _):
            name
        case let .annotated(name, _):
            name
        }
    }

    /// The short human-readable name of the branch (e.g., `master`).
    public var name: String {
        String(longName["refs/tags/".endIndex...]) // String(longName["refs/tags/".endIndex...])
    }

    /// The OID of the target object.
    ///
    /// If this is an annotated tag, the OID will be the tag's target.
    public var oid: OID {
        switch self {
        case let .lightweight(_, oid):
            oid
        case let .annotated(_, tag):
            tag.target.oid
        }
    }

    // MARK: Derived Properties

    /// The short human-readable name of the branch (e.g., `master`).
    ///
    /// This is the same as `name`, but is declared with an Optional type to adhere to
    /// `ReferenceType`.
    public var shortName: String? {
        name
    }

    /// Create an instance with a libgit2 `git_reference` object.
    ///
    /// Returns `nil` if the pointer isn't a branch.
    public init?(_ pointer: OpaquePointer) {
        if git_reference_is_tag(pointer) == 0 {
            return nil
        }

        let name = String(validatingUTF8: git_reference_name(pointer))!
        let repo = git_reference_owner(pointer)
        var oid = git_reference_target(pointer).pointee

        var pointer: OpaquePointer?
        let result = git_object_lookup(&pointer, repo, &oid, GIT_OBJECT_TAG)
        if result == GIT_OK.rawValue {
            self = .annotated(name, Tag(pointer!))
        } else {
            self = .lightweight(name, OID(oid))
        }
        git_object_free(pointer)
    }
}

/// An annotated git tag.
public struct Tag: ObjectType, Hashable {
    public static let type = GIT_OBJECT_TAG

    /// The OID of the tag.
    public let oid: OID

    /// The tagged object.
    public let target: Pointer

    /// The name of the tag.
    public let name: String

    /// The tagger (author) of the tag.
    public let tagger: Signature

    /// The message of the tag.
    public let message: String

    /// Create an instance with a libgit2 `git_tag`.
    public init(_ pointer: OpaquePointer) {
        self.oid = OID(git_object_id(pointer).pointee)
        let targetOID = OID(git_tag_target_id(pointer).pointee)
        self.target = Pointer(oid: targetOID, type: git_tag_target_type(pointer))!
        self.name = String(validatingUTF8: git_tag_name(pointer))!
        self.tagger = Signature(git_tag_tagger(pointer).pointee)
        self.message = String(validatingUTF8: git_tag_message(pointer))!
    }
}
