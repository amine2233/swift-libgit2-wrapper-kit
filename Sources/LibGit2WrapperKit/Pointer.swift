import Foundation
import Libgit2Module

/// A pointer to a git object.
public protocol PointerType: Hashable {
    /// The OID of the referenced object.
    var oid: OID { get }

    /// The libgit2 `git_object_t` of the referenced object.
    var type: git_object_t { get }
}

extension PointerType {
    /// Two pointers are equal when they share the same OID and object type.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.oid == rhs.oid
            && lhs.type == rhs.type
    }

    /// Hashes the pointer by its OID.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(oid)
    }
}

/// A pointer to a git object.
public enum Pointer: PointerType {
    case commit(OID)
    case tree(OID)
    case blob(OID)
    case tag(OID)

    public var oid: OID {
        switch self {
        case let .commit(oid):
            oid
        case let .tree(oid):
            oid
        case let .blob(oid):
            oid
        case let .tag(oid):
            oid
        }
    }

    public var type: git_object_t {
        switch self {
        case .commit:
            GIT_OBJECT_COMMIT
        case .tree:
            GIT_OBJECT_TREE
        case .blob:
            GIT_OBJECT_BLOB
        case .tag:
            GIT_OBJECT_TAG
        }
    }

    /// Create an instance with an OID and a libgit2 `git_object_t`.
    init?(oid: OID, type: git_object_t) {
        switch type {
        case GIT_OBJECT_COMMIT:
            self = .commit(oid)
        case GIT_OBJECT_TREE:
            self = .tree(oid)
        case GIT_OBJECT_BLOB:
            self = .blob(oid)
        case GIT_OBJECT_TAG:
            self = .tag(oid)
        default:
            return nil
        }
    }
}

extension Pointer: CustomStringConvertible {
    public var description: String {
        switch self {
        case .commit:
            "commit(\(oid))"
        case .tree:
            "tree(\(oid))"
        case .blob:
            "blob(\(oid))"
        case .tag:
            "tag(\(oid))"
        }
    }
}

public struct PointerTo<T: ObjectType>: PointerType {
    public let oid: OID

    public var type: git_object_t {
        T.type
    }

    public init(_ oid: OID) {
        self.oid = oid
    }
}
