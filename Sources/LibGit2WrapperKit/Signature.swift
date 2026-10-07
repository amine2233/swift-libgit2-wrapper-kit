import Foundation
import Libgit2Module

/// The `Signature`
public struct Signature {
    /// The name of the person.
    public let name: String

    /// The email of the person.
    public let email: String

    /// The time when the action happened.
    public let time: Date

    /// The time zone that `time` should be interpreted relative to.
    public let timeZone: TimeZone

    /// Create an instance with custom name, email, dates, etc.
    public init(
        name: String,
        email: String,
        time: Date = Date(),
        timeZone: TimeZone = TimeZone.autoupdatingCurrent
    ) {
        self.name = name
        self.email = email
        self.time = time
        self.timeZone = timeZone
    }

    /// Create an instance with a libgit2 `git_signature`.
    public init(_ signature: git_signature) {
        self.name = String(validatingUTF8: signature.name)!
        self.email = String(validatingUTF8: signature.email)!
        self.time = Date(timeIntervalSince1970: TimeInterval(signature.when.time))
        self.timeZone = TimeZone(secondsFromGMT: 60 * Int(signature.when.offset))!
    }

    /// Return an unsafe pointer to the `git_signature` struct.
    /// Caller is responsible for freeing it with `git_signature_free`.
    func makeUnsafeSignature() -> Result<UnsafeMutablePointer<git_signature>, NSError> {
        var signature: UnsafeMutablePointer<git_signature>?
        let time = git_time_t(time.timeIntervalSince1970) // Unix epoch time
        let offset = Int32(timeZone.secondsFromGMT(for: self.time) / 60)
        let signatureResult = git_signature_new(&signature, name, email, time, offset)
        guard signatureResult == GIT_OK.rawValue, let signatureUnwrap = signature else {
            let err = NSError(gitError: signatureResult, pointOfFailure: "git_signature_new")
            return .failure(err)
        }

        return .success(signatureUnwrap)
    }
}

extension Signature: Hashable {
    /// Hashes the essential components of this value by feeding them into the
    /// given hasher.
    ///
    /// Implement this method to conform to the `Hashable` protocol. The
    /// components used for hashing must be the same as the components compared
    /// in your type's `==` operator implementation. Call `hasher.combine(_:)`
    /// with each of these components.
    ///
    /// - Important: Never call `finalize()` on `hasher`. Doing so may become a
    ///   compile-time error in the future.
    ///
    /// - Parameter hasher: The hasher to use when combining the components
    ///   of this instance.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(email)
        hasher.combine(time)
    }
}
