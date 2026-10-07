import Foundation
import Libgit2Module

/// A git tree.
public struct Tree: ObjectType, Hashable {
    public static let type = GIT_OBJECT_TREE

    /// An entry in a `Tree`.
    public struct Entry: Hashable {
        /// The entry's UNIX file attributes.
        public let attributes: Int32

        /// The object pointed to by the entry.
        public let object: Pointer

        /// The file name of the entry.
        public let name: String

        /// Create an instance with a libgit2 `git_tree_entry`.
        public init(_ pointer: OpaquePointer) {
            let oid = OID(git_tree_entry_id(pointer).pointee)
            self.attributes = Int32(git_tree_entry_filemode(pointer).rawValue)
            self.object = Pointer(oid: oid, type: git_tree_entry_type(pointer))!
            self.name = String(validatingUTF8: git_tree_entry_name(pointer))!
        }

        /// Create an instance with the individual values.
        public init(attributes: Int32, object: Pointer, name: String) {
            self.attributes = attributes
            self.object = object
            self.name = name
        }
    }

    /// The OID of the tree.
    public let oid: OID

    /// The entries in the tree.
    public let entries: [String: Entry]

    /// Create an instance with a libgit2 `git_tree`.
    public init(_ pointer: OpaquePointer) {
        self.oid = OID(git_object_id(pointer).pointee)

        var entries: [String: Entry] = [:]
        for idx in 0 ..< git_tree_entrycount(pointer) {
            let entry = Entry(git_tree_entry_byindex(pointer, idx)!)
            entries[entry.name] = entry
        }
        self.entries = entries
    }
}

extension Tree.Entry: CustomStringConvertible {
    public var description: String {
        "\(attributes) \(object) \(name)"
    }
}
