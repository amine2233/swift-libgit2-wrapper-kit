import Foundation
import Libgit2Module

/// A set of file differences between two git trees or states.
public struct Diff {
    /// The set of deltas.
    public var deltas = [Delta]()

    /// A single file change within a diff.
    public struct Delta {
        /// The libgit2 object type of a delta.
        public static let type = GIT_OBJECT_REF_DELTA

        /// The kind of change applied to the file.
        public var status: Status
        /// The delta flags.
        public var flags: Flags
        /// The file before the change.
        public var oldFile: File?
        /// The file after the change.
        public var newFile: File?

        /// Create an instance with a libgit2 `git_diff_delta`.
        public init(_ delta: git_diff_delta) {
            self.status = Status(rawValue: UInt32(git_diff_status_char(delta.status)))
            self.flags = Flags(rawValue: delta.flags)
            self.oldFile = File(delta.old_file)
            self.newFile = File(delta.new_file)
        }
    }

    /// One side of a delta: a file as it exists on either side of the diff.
    public struct File {
        /// The OID of the file content.
        public var oid: OID
        /// The path of the file relative to the repository root.
        public var path: String
        /// The size of the file in bytes.
        public var size: UInt64
        /// The file flags.
        public var flags: Flags

        /// Create an instance with a libgit2 `git_diff_file`.
        public init(_ diffFile: git_diff_file) {
            self.oid = OID(diffFile.id)
            let path = diffFile.path
            self.path = path.map(String.init(cString:))!
            self.size = diffFile.size
            self.flags = Flags(rawValue: diffFile.flags)
        }
    }

    public struct Status: OptionSet, Sendable {
        /// This appears to be necessary due to bug in Swift
        /// https://bugs.swift.org/browse/SR-3003
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public let rawValue: UInt32

        public static let current = Status(rawValue: GIT_STATUS_CURRENT.rawValue)
        public static let indexNew = Status(rawValue: GIT_STATUS_INDEX_NEW.rawValue)
        public static let indexModified = Status(rawValue: GIT_STATUS_INDEX_MODIFIED.rawValue)
        public static let indexDeleted = Status(rawValue: GIT_STATUS_INDEX_DELETED.rawValue)
        public static let indexRenamed = Status(rawValue: GIT_STATUS_INDEX_RENAMED.rawValue)
        public static let indexTypeChange = Status(rawValue: GIT_STATUS_INDEX_TYPECHANGE.rawValue)
        public static let workTreeNew = Status(rawValue: GIT_STATUS_WT_NEW.rawValue)
        public static let workTreeModified = Status(rawValue: GIT_STATUS_WT_MODIFIED.rawValue)
        public static let workTreeDeleted = Status(rawValue: GIT_STATUS_WT_DELETED.rawValue)
        public static let workTreeTypeChange = Status(rawValue: GIT_STATUS_WT_TYPECHANGE.rawValue)
        public static let workTreeRenamed = Status(rawValue: GIT_STATUS_WT_RENAMED.rawValue)
        public static let workTreeUnreadable = Status(rawValue: GIT_STATUS_WT_UNREADABLE.rawValue)
        public static let ignored = Status(rawValue: GIT_STATUS_IGNORED.rawValue)
        public static let conflicted = Status(rawValue: GIT_STATUS_CONFLICTED.rawValue)
    }

    public struct Flags: OptionSet, Sendable {
        /// This appears to be necessary due to bug in Swift
        /// https://bugs.swift.org/browse/SR-3003
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public let rawValue: UInt32

        public static let binary = Flags([])
        public static let notBinary = Flags(rawValue: 1 << 0)
        public static let validId = Flags(rawValue: 1 << 1)
        public static let exists = Flags(rawValue: 1 << 2)
    }

    /// Create an instance with a libgit2 `git_diff`.
    public init(_ pointer: OpaquePointer) {
        for i in 0 ..< git_diff_num_deltas(pointer) {
            if let delta = git_diff_get_delta(pointer, i) {
                deltas.append(Diff.Delta(delta.pointee))
            }
        }
    }
}
