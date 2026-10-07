import Foundation
import Libgit2Module

extension Repository {
    // MARK: - Object Lookups

    /// Load a libgit2 object and transform it to something else.
    ///
    /// oid       - The OID of the object to look up.
    /// type      - The type of the object to look up.
    /// transform - A function that takes the libgit2 object and transforms it
    ///             into something else.
    ///
    /// Returns the result of calling `transform` or an error if the object
    /// cannot be loaded.
    func withGitObject<T>(
        _ oid: OID,
        type: git_object_t,
        transform: (OpaquePointer) -> Result<T, NSError>
    ) -> Result<T, NSError> {
        var pointer: OpaquePointer?
        var oid = oid.oid
        let result = git_object_lookup(&pointer, self.pointer, &oid, type)

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_object_lookup"))
        }

        let value = transform(pointer!)
        git_object_free(pointer)
        return value
    }

    func withGitObject<T>(
        _ oid: OID,
        type: git_object_t,
        transform: (OpaquePointer) -> T
    ) -> Result<T, NSError> {
        withGitObject(oid, type: type) { Result.success(transform($0)) }
    }

    func withGitObjects<T>(
        _ oids: [OID],
        type: git_object_t,
        transform: ([OpaquePointer]) -> Result<T, NSError>
    ) -> Result<T, NSError> {
        var pointers = [OpaquePointer]()
        defer {
            for pointer in pointers {
                git_object_free(pointer)
            }
        }

        for oid in oids {
            var pointer: OpaquePointer?
            var oid = oid.oid
            let result = git_object_lookup(&pointer, self.pointer, &oid, type)

            guard result == GIT_OK.rawValue else {
                return Result.failure(NSError(gitError: result, pointOfFailure: "git_object_lookup"))
            }

            pointers.append(pointer!)
        }

        return transform(pointers)
    }

    /// Loads the object with the given OID.
    ///
    /// oid - The OID of the blob to look up.
    ///
    /// Returns a `Blob`, `Commit`, `Tag`, or `Tree` if one exists, or an error.
    public func object(_ oid: OID) -> Result<ObjectType, NSError> {
        withGitObject(oid, type: GIT_OBJECT_ANY) { object in
            let type = git_object_type(object)
            if type == Blob.type {
                return Result.success(Blob(object))
            } else if type == Commit.type {
                return Result.success(Commit(object))
            } else if type == Tag.type {
                return Result.success(Tag(object))
            } else if type == Tree.type {
                return Result.success(Tree(object))
            }

            let error = NSError(
                domain: "org.libgit2.SwiftGit2",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unrecognized git_object_t '\(type)' for oid '\(oid)'."
                ]
            )
            return Result.failure(error)
        }
    }

    /// Loads the blob with the given OID.
    ///
    /// oid - The OID of the blob to look up.
    ///
    /// Returns the blob if it exists, or an error.
    public func blob(_ oid: OID) -> Result<Blob, NSError> {
        withGitObject(oid, type: GIT_OBJECT_BLOB) { Blob($0) }
    }

    /// Loads the commit with the given OID.
    ///
    /// oid - The OID of the commit to look up.
    ///
    /// Returns the commit if it exists, or an error.
    public func commit(_ oid: OID) -> Result<Commit, NSError> {
        withGitObject(oid, type: GIT_OBJECT_COMMIT) { Commit($0) }
    }

    /// Loads the tag with the given OID.
    ///
    /// oid - The OID of the tag to look up.
    ///
    /// Returns the tag if it exists, or an error.
    public func tag(_ oid: OID) -> Result<Tag, NSError> {
        withGitObject(oid, type: GIT_OBJECT_TAG) { Tag($0) }
    }

    /// Loads the tree with the given OID.
    ///
    /// oid - The OID of the tree to look up.
    ///
    /// Returns the tree if it exists, or an error.
    public func tree(_ oid: OID) -> Result<Tree, NSError> {
        withGitObject(oid, type: GIT_OBJECT_TREE) { Tree($0) }
    }

    /// Loads the referenced object from the pointer.
    ///
    /// pointer - A pointer to an object.
    ///
    /// Returns the object if it exists, or an error.
    public func object<T>(from pointer: PointerTo<T>) -> Result<T, NSError> {
        withGitObject(pointer.oid, type: pointer.type) { T($0) }
    }

    /// Loads the referenced object from the pointer.
    ///
    /// pointer - A pointer to an object.
    ///
    /// Returns the object if it exists, or an error.
    public func object(from pointer: Pointer) -> Result<ObjectType, NSError> {
        switch pointer {
        case let .blob(oid):
            blob(oid).map { $0 as ObjectType }
        case let .commit(oid):
            commit(oid).map { $0 as ObjectType }
        case let .tag(oid):
            tag(oid).map { $0 as ObjectType }
        case let .tree(oid):
            tree(oid).map { $0 as ObjectType }
        }
    }
}
