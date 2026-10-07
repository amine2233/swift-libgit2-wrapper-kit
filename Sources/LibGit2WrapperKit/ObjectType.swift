import Foundation
import Libgit2Module

/// A git object.
public protocol ObjectType {
    static var type: git_object_t { get }

    /// The OID of the object.
    var oid: OID { get }

    /// Create an instance with the underlying libgit2 type.
    init(_ pointer: OpaquePointer)
}

extension ObjectType {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.oid == rhs.oid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(oid)
    }
}
