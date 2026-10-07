import Foundation
import Libgit2Module

/// A git object.
public protocol ObjectType {
    /// The libgit2 object type backing this type.
    static var type: git_object_t { get }

    /// The OID of the object.
    var oid: OID { get }

    /// Create an instance with the underlying libgit2 type.
    init(_ pointer: OpaquePointer)
}

extension ObjectType {
    /// Two objects are equal when they share the same OID.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.oid == rhs.oid
    }

    /// Hashes the object by its OID.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(oid)
    }
}
