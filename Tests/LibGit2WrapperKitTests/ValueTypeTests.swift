import Foundation
import Testing
@testable import LibGit2WrapperKit

struct ValueTypeTests {
    @Test
    func credentialsEqualityComparesAssociatedValues() {
        #expect(Credentials.default == .default)
        #expect(Credentials.sshAgent == .sshAgent)
        #expect(Credentials.default != .sshAgent)
        #expect(Credentials.plaintext(username: "u", password: "p") == .plaintext(
            username: "u",
            password: "p"
        ))
        #expect(Credentials.plaintext(username: "u", password: "p") != .plaintext(
            username: "u",
            password: "x"
        ))
        #expect(
            Credentials.sshMemory(username: "git", publicKey: "pub", privateKey: "priv", passphrase: "")
                != .sshMemory(username: "git", publicKey: "pub", privateKey: "other", passphrase: "")
        )
    }

    @Test
    func signatureKeepsProvidedFields() {
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        let signature = Signature(name: "Tester", email: "t@example.com", time: time, timeZone: .gmt)

        #expect(signature.name == "Tester")
        #expect(signature.email == "t@example.com")
        #expect(signature.time == time)
        #expect(signature.timeZone == .gmt)
    }

    @Test
    func signaturesWithSameFieldsAreEqualAndHashEqually() {
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        let lhs = Signature(name: "Tester", email: "t@example.com", time: time, timeZone: .gmt)
        let rhs = Signature(name: "Tester", email: "t@example.com", time: time, timeZone: .gmt)

        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
    }

    @Test
    func statusOptionsCombine() {
        let options: StatusOptions = [.includeUntracked, .includeIgnored]

        #expect(options.contains(.includeUntracked))
        #expect(options.contains(.includeIgnored))
        #expect(!options.contains(.includeUnmodified))
    }

    @Test
    func diffFlagsAndStatusAreOptionSets() {
        #expect(Diff.Flags([.exists, .validId]).contains(.exists))
        #expect(!Diff.Flags([.exists]).contains(.validId))
        #expect(Diff.Status([.indexNew, .workTreeModified]).contains(.workTreeModified))
    }

    @Test
    func proxyConfigurationDefaultsToNoProxy() {
        let proxy = ProxyConfiguration()

        #expect(proxy.url == nil)
        #expect(proxy.credential == nil)
    }
}
