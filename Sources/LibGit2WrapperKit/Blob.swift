import Foundation
import Libgit2Module

/// A git blob.
public struct Blob: ObjectType, Hashable {
    public static let type = GIT_OBJECT_BLOB

    /// The OID of the blob.
    public let oid: OID

    /// The contents of the blob.
    public let data: Data

    /// Create an instance with a libgit2 `git_blob`.
    public init(_ pointer: OpaquePointer) {
        self.oid = OID(git_object_id(pointer).pointee)

        let length = Int(git_blob_rawsize(pointer))
        self.data = Data(bytes: git_blob_rawcontent(pointer), count: length)
    }
}
