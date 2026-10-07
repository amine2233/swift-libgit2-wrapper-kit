import Testing
@testable import LibGit2WrapperKit

struct OIDTests {
    private let hex = "0123456789abcdef0123456789abcdef01234567"

    @Test
    func initFromValidStringRoundTrips() throws {
        let oid = try #require(OID(string: hex))
        #expect(oid.description == hex)
    }

    @Test(arguments: ["not-hex", "zz", String(repeating: "a", count: 41)])
    func initFromInvalidStringFails(_ string: String) {
        #expect(OID(string: string) == nil)
    }

    @Test
    func equalOIDsHashEqually() throws {
        let lhs = try #require(OID(string: hex))
        let rhs = try #require(OID(string: hex))
        #expect(lhs == rhs)
        #expect(lhs.hashValue == rhs.hashValue)
    }

    @Test
    func differentOIDsAreNotEqual() throws {
        let lhs = try #require(OID(string: hex))
        let rhs = try #require(OID(string: String(repeating: "f", count: 40)))
        #expect(lhs != rhs)
    }
}
