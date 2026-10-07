import Foundation
import Libgit2Module

final class Wrapper<T> {
    let value: T

    init(_ value: T) {
        self.value = value
    }
}

/// The `Credentials`
public enum Credentials: CustomStringConvertible {
    case `default`
    case sshAgent
    case plaintext(username: String, password: String)
    case sshMemory(username: String?, publicKey: String, privateKey: String, passphrase: String)

    static func fromPointer(_ pointer: UnsafeMutableRawPointer) -> Credentials {
        Unmanaged<Wrapper<Credentials>>.fromOpaque(UnsafeRawPointer(pointer)).takeUnretainedValue()
            .value
    }

    func toPointer() -> UnsafeMutableRawPointer {
        Unmanaged.passRetained(Wrapper(self)).toOpaque()
    }

    /// A textual representation of this instance.
    public var description: String {
        switch self {
        case .default: "default"
        case .sshAgent: "ssh_agent"
        case .plaintext: "plaintext"
        case .sshMemory: "sshMemory"
        }
    }
}

/// Git Proxy Configuration
public struct ProxyConfiguration {
    /// The proxy url
    public let url: URL?
    /// The credential url
    public let credential: ProxyCredential?

    /// Create a new proxy configuration
    /// - Parameters:
    ///   - url: the proxy url
    ///   - credential: the proxy credential
    public init(url: URL? = nil, credential: ProxyCredential? = nil) {
        self.url = url
        self.credential = credential
    }
}

/// The proxy Credential
public struct ProxyCredential {
    /// The proxy username
    public let username: String?
    /// The proxy password
    public let password: String?

    /// Create a new `ProxyCredential`
    /// - Parameters:
    ///   - username: the proxy username
    ///   - password: the proxy password
    public init(username: String?, password: String?) {
        self.username = username
        self.password = password
    }

    static func fromPointer(_ pointer: UnsafeMutableRawPointer) -> ProxyCredential {
        Unmanaged<Wrapper<ProxyCredential>>.fromOpaque(UnsafeRawPointer(pointer)).takeUnretainedValue()
            .value
    }

    func toPointer() -> UnsafeMutableRawPointer {
        Unmanaged.passRetained(Wrapper(self)).toOpaque()
    }
}

extension Credentials: Equatable {
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func == (lhs: Credentials, rhs: Credentials) -> Bool {
        switch lhs {
        case .default: if case .default = rhs { true } else { false }
        case .sshAgent: if case .sshAgent = rhs { true } else { false }
        case let .plaintext(username, password):
            if case let .plaintext(username2, password2) = rhs,
               username == username2,
               password == password2 {
                true
            } else {
                false
            }
        case let .sshMemory(username, publicKey, privateKey, passphrase):
            if case let .sshMemory(username2, publicKey2, privateKey2, passphrase2) = rhs,
               username == username2,
               publicKey == publicKey2,
               privateKey == privateKey2,
               passphrase == passphrase2 {
                true
            } else {
                false
            }
        }
    }
}

/// Handle the request of credentials, passing through to a wrapped block after converting the arguments.
/// Converts the result to the correct error code required by libgit2 (0 = success, 1 = rejected setting
/// creds,
/// -1 = error)
func credentialsCallback(
    credential: UnsafeMutablePointer<UnsafeMutablePointer<git_credential>?>?,
    url _: UnsafePointer<CChar>?,
    urlUsername: UnsafePointer<CChar>?,
    _: UInt32,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    var result: Int32 = GIT_EUSER.rawValue

    guard let payload else { return result }

    // Find username_from_url if is git@github.com:username/repository.git otherwise we have an error
    // if is https we need to provide a username
    // if is sshAgent or sshKey we can use username on url or provide a username
    // otherwise we send a failure
    let name = urlUsername.map(String.init(cString:))

    switch Credentials.fromPointer(payload) {
    case .default:
        result = git_credential_default_new(credential)
    case .sshAgent:
        guard let user = name else { return result }

        result = git_credential_ssh_key_from_agent(credential, user)
    case let .plaintext(username, password):
        result = git_credential_userpass_plaintext_new(credential, username, password)
    case let .sshMemory(username, publicKey, privateKey, passphrase):
        guard let user = name ?? username else { return result }

        result = git_credential_ssh_key_memory_new(credential, user, publicKey, privateKey, passphrase)
    }

    return (result != GIT_OK.rawValue) ? -1 : 0
}

func credentialsProxyCallback(
    credential: UnsafeMutablePointer<UnsafeMutablePointer<git_credential>?>?,
    url _: UnsafePointer<CChar>?,
    urlUsername: UnsafePointer<CChar>?,
    _: UInt32,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    var result: Int32 = GIT_EUSER.rawValue

    guard let payload else { return result }

    // Find username_from_url if is git@github.com:username/repository.git otherwise we have an error
    // if is https we need to provide a username
    // if is sshAgent or sshKey we can use username on url or provide a username
    // otherwise we send a failure
    let name = urlUsername.map(String.init(cString:))

    let proxyCredential = ProxyCredential.fromPointer(payload)

    result = git_credential_userpass_plaintext_new(
        credential, proxyCredential.username ?? name, proxyCredential.password
    )

    return result
}

func certificateCheckCallback(
    gitCert _: UnsafeMutablePointer<git_cert>?,
    valid _: Int32,
    url _: UnsafePointer<Int8>?,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    guard let payload else { return GIT_OK.rawValue }

    let value = Unmanaged<Wrapper<Int>>.fromOpaque(UnsafeRawPointer(payload)).takeUnretainedValue().value

    if value > 0 {
        print("success")
        return GIT_OK.rawValue
    } else {
        print("fail")
        return GIT_OK.rawValue
    }
}

func certificateCheckProxyCallback(
    gitCert _: UnsafeMutablePointer<git_cert>?,
    valid _: Int32,
    url _: UnsafePointer<Int8>?,
    payload: UnsafeMutableRawPointer?
) -> Int32 {
    guard let payload else { return GIT_OK.rawValue }

    let value = Unmanaged<Wrapper<Int>>.fromOpaque(UnsafeRawPointer(payload)).takeUnretainedValue().value

    // Maybe need to fix some issue with certificate here
    // let result = git_cert(cert_type: GIT_CERT_HOSTKEY_LIBSSH2)

    if value > 0 {
        return GIT_OK.rawValue
    } else {
        return GIT_OK.rawValue
    }
}
