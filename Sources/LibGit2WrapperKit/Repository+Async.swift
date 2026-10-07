import Foundation

// libgit2 calls are blocking. These methods run them off the caller's executor so UI code can `await` them.
// A `Repository` must not be used by two operations at the same time.

extension Repository {
    /// Clone the repository at `remoteURL` into `localURL` without blocking the caller.
    ///
    /// See ``clone(from:to:localClone:bare:credentials:checkoutStrategy:proxy:checkoutProgress:)`` for the
    /// meaning of each parameter.
    public static func clone(
        from remoteURL: URL,
        to localURL: URL,
        localClone: Bool = false,
        bare: Bool = false,
        credentials: Credentials = .default,
        checkoutStrategy: CheckoutStrategy = .Safe,
        proxy: ProxyConfiguration?,
        checkoutProgress: (@Sendable (String?, Int, Int) -> Void)? = nil
    ) async throws -> Repository {
        try clone(
            from: remoteURL,
            to: localURL,
            localClone: localClone,
            bare: bare,
            credentials: credentials,
            checkoutStrategy: checkoutStrategy,
            proxy: proxy,
            checkoutProgress: checkoutProgress
        ).get()
    }

    /// Download new objects from `remote` and update its remote-tracking branches without blocking the
    /// caller.
    public func fetch(
        _ remote: Remote,
        credentials: Credentials = .default,
        proxy: ProxyConfiguration?
    ) async throws {
        try fetch(remote, credentials: credentials, proxy: proxy).get()
    }

    /// Push `branch` to `remote` without blocking the caller.
    public func push(
        remote: Remote,
        branch: Branch,
        credentials: Credentials? = nil,
        proxy: ProxyConfiguration? = nil
    ) async throws {
        try push2(remote: remote, branch: branch, credentials: credentials, proxy: proxy).get()
    }

    /// Fetch `remote`, then merge `branch` into the local branch of the same name, without blocking the
    /// caller.
    public func pull(
        remote: Remote,
        branch: Branch,
        author: String,
        email: String,
        credentials: Credentials = .default,
        proxy: ProxyConfiguration?,
        conflictResolver: @escaping @Sendable (Data, Data) -> ConflictResolutionDecision
    ) async throws {
        try pull(
            remote: remote,
            branch: branch,
            author: author,
            email: email,
            credentials: credentials,
            proxy: proxy,
            conflictResolver: conflictResolver
        ).get()
    }
}
