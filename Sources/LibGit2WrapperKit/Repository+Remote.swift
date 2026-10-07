import Foundation
import Libgit2Module

extension Repository {
    // MARK: - Remote Lookups

    /// Loads all the remotes in the repository.
    ///
    /// Returns an array of remotes, or an error.
    public func allRemotes() -> Result<[Remote], NSError> {
        let pointer = UnsafeMutablePointer<git_strarray>.allocate(capacity: 1)
        let result = git_remote_list(pointer, self.pointer)

        guard result == GIT_OK.rawValue else {
            pointer.deallocate()
            return Result.failure(NSError(gitError: result, pointOfFailure: "git_remote_list"))
        }

        let strarray = pointer.pointee
        let remotes: [Result<Remote, NSError>] = strarray.map {
            self.remote(named: $0)
        }
        git_strarray_dispose(pointer)
        pointer.deallocate()

        return remotes.aggregateResult()
    }

    func remoteLookup<A>(named name: String, _ callback: (Result<OpaquePointer, NSError>) -> A) -> A {
        var pointer: OpaquePointer?
        defer { git_remote_free(pointer) }

        let result = git_remote_lookup(&pointer, self.pointer, name)

        guard result == GIT_OK.rawValue else {
            return callback(.failure(NSError(gitError: result, pointOfFailure: "git_remote_lookup")))
        }

        return callback(.success(pointer!))
    }

    /// Load a remote from the repository.
    ///
    /// name - The name of the remote.
    ///
    /// Returns the remote if it exists, or an error.
    public func remote(named name: String) -> Result<Remote, NSError> {
        remoteLookup(named: name) { $0.map(Remote.init) }
    }

    /// Download new data and update tips
    /// - Parameters:
    ///   - remote: The remote object
    ///   - proxy: The proxy object
    /// - Returns: Result void or failure
    public func fetch(_ remote: Remote, proxy: ProxyConfiguration?) -> Result<Void, NSError> {
        remoteLookup(named: remote.name) { remote in
            remote.flatMap { pointer in
                var opts = fetchOptions(credentials: .sshAgent, proxy: proxy)
                let resultInit = git_fetch_options_init(&opts, UInt32(GIT_FETCH_OPTIONS_VERSION))
                assert(resultInit == GIT_OK.rawValue)

                let result = git_remote_fetch(pointer, nil, &opts, nil)
                guard result == GIT_OK.rawValue else {
                    let err = NSError(gitError: result, pointOfFailure: "git_remote_fetch")
                    return .failure(err)
                }

                return .success(())
            }
        }
    }

    /// Fetch git repository
    /// - Parameters:
    ///   - remote: The remote repository information
    ///   - credentials: The credential information
    ///   - proxy: The proxy infirmation
    /// - Returns: Return a `Result<Void, NSError>`
    public func fetch(
        _ remote: Remote,
        credentials: Credentials = .default,
        proxy: ProxyConfiguration?
    ) -> Result<Void, NSError> {
        remoteLookup(named: remote.name) { remote in
            remote.flatMap { pointer in
                var opts: git_fetch_options
                if credentials != Credentials.default {
                    opts = fetchOptions(credentials: credentials, proxy: proxy)
                } else {
                    opts = git_fetch_options()
                    let resultInit = git_fetch_options_init(&opts, UInt32(GIT_FETCH_OPTIONS_VERSION))
                    assert(resultInit == GIT_OK.rawValue)
                }

                let result = git_remote_fetch(pointer, nil, &opts, nil)
                guard result == GIT_OK.rawValue else {
                    let err = NSError(gitError: result, pointOfFailure: "git_remote_fetch")
                    return .failure(err)
                }

                return .success(())
            }
        }
    }
}
