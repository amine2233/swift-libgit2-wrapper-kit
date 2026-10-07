import Foundation
import Libgit2Module

/// libgit2 requires a global initialization before most operations; Swift runs this once, lazily.
let libgit2Initialization = git_libgit2_init()

/// A git repository.
/// Git `Repository` class
public final class Repository: @unchecked Sendable { // swiftlint:disable:this type_body_length
    // MARK: - Creating Repositories

    /// Create a new repository at the given URL.
    ///
    /// URL - The URL of the repository.
    ///
    /// Returns a `Result` with a `Repository` or an error.
    public static func create(at url: URL) -> Result<Repository, NSError> {
        var pointer: OpaquePointer?
        let result = url.withUnsafeFileSystemRepresentation {
            git_repository_init(&pointer, $0, 0)
        }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_init"))
        }

        let repository = Repository(pointer!)
        return Result.success(repository)
    }

    /// Load the repository at the given URL.
    ///
    /// URL - The URL of the repository.
    ///
    /// Returns a `Result` with a `Repository` or an error.
    public static func at(_ url: URL) -> Result<Repository, NSError> {
        var pointer: OpaquePointer?
        let result = url.withUnsafeFileSystemRepresentation {
            git_repository_open(&pointer, $0)
        }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_repository_open"))
        }

        let repository = Repository(pointer!)
        return Result.success(repository)
    }

    /// Clone the repository from a given URL.
    ///
    /// remoteURL        - The URL of the remote repository
    /// localURL         - The URL to clone the remote repository into
    /// localClone       - Will not bypass the git-aware transport, even if remote is local.
    /// bare             - Clone remote as a bare repository.
    /// credentials      - Credentials to be used when connecting to the remote.
    /// checkoutStrategy - The checkout strategy to use, if being checked out.
    /// checkoutProgress - A block that's called with the progress of the checkout.
    /// proxy            - A proxy configuration
    ///
    /// Returns a `Result` with a `Repository` or an error.
    public static func clone(
        from remoteURL: URL,
        to localURL: URL,
        localClone: Bool = false,
        bare: Bool = false,
        credentials: Credentials = .default,
        checkoutStrategy: CheckoutStrategy = .Safe,
        proxy: ProxyConfiguration?,
        checkoutProgress: CheckoutProgressBlock? = nil
    ) -> Result<Repository, NSError> {
        _ = libgit2Initialization
        var options = cloneOptions(
            bare: bare,
            localClone: localClone,
            fetchOptions: fetchOptions(credentials: credentials, proxy: proxy),
            checkoutOptions: checkoutOptions(strategy: checkoutStrategy, progress: checkoutProgress)
        )

        var pointer: OpaquePointer?
        let remoteURLString = (remoteURL as NSURL).isFileReferenceURL() ? remoteURL.path : remoteURL
            .absoluteString
        let result = localURL.withUnsafeFileSystemRepresentation { localPath in
            git_clone(&pointer, remoteURLString, localPath, &options)
        }

        guard result == GIT_OK.rawValue else {
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_clone"))
        }

        let repository = Repository(pointer!)
        return Result.success(repository)
    }

    // MARK: - Initializers

    /// Create an instance with a libgit2 `git_repository` object.
    ///
    /// The Repository assumes ownership of the `git_repository` object.
    public init(_ pointer: OpaquePointer) {
        git_libgit2_init()
        self.pointer = pointer

        let path = git_repository_workdir(pointer)
        self.directoryURL = path
            .map { URL(fileURLWithPath: String(validatingCString: $0)!, isDirectory: true) }
    }

    static func fromPointer(_ pointer: UnsafeMutableRawPointer) -> Repository {
        Unmanaged<Wrapper<Repository>>.fromOpaque(UnsafeRawPointer(pointer)).takeRetainedValue().value
    }

    deinit {
        git_repository_free(pointer)
        git_libgit2_shutdown()
    }

    // MARK: - Properties

    /// The underlying libgit2 `git_repository` object.
    public let pointer: OpaquePointer

    /// The URL of the repository's working directory, or `nil` if the
    /// repository is bare.
    public let directoryURL: URL?

    // MARK: - Validity/Existence Check

    /// - returns: `.success(true)` iff there is a git repository at `url`,
    ///   `.success(false)` if there isn't,
    ///   and a `.failure` if there's been an error.
    public static func isValid(url: URL) -> Result<Bool, NSError> {
        var pointer: OpaquePointer?

        let result = url.withUnsafeFileSystemRepresentation {
            git_repository_open_ext(&pointer, $0, GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue, nil)
        }

        switch result {
        case GIT_ENOTFOUND.rawValue:
            return .success(false)
        case GIT_OK.rawValue:
            return .success(true)
        default:
            return .failure(NSError(gitError: result, pointOfFailure: "git_repository_open_ext"))
        }
    }
}
