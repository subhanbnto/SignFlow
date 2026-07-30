import XCTest
import Security
@testable import SignFlow

final class PKCS12ParserTests: XCTestCase {
    func testCorrectPasswordParsesIdentity() throws {
        let data = try Data(contentsOf: CredentialFixtures.p12URL)
        let parsed = try PKCS12Parser.parse(data: data, password: CredentialFixtures.p12Password)

        XCTAssertEqual(parsed.metadata.fingerprintSHA256, CredentialFixtures.expectedFingerprint)
        XCTAssertTrue(parsed.metadata.commonName.contains("SignFlow Test Developer"))
        XCTAssertEqual(parsed.metadata.teamIdentifier, CredentialFixtures.expectedTeamHint)
        XCTAssertGreaterThan(parsed.metadata.expiresAt, Date())
    }

    func testIncorrectPasswordThrows() throws {
        let data = try Data(contentsOf: CredentialFixtures.p12URL)
        XCTAssertThrowsError(try PKCS12Parser.parse(data: data, password: "wrong-password")) { error in
            guard let sfError = error as? SignFlowError else {
                return XCTFail("Wrong type \(error)")
            }
            switch sfError {
            case .incorrectP12Password, .invalidP12:
                break
            default:
                XCTFail("Unexpected \(sfError)")
            }
        }
    }

    func testInvalidDataThrows() {
        let junk = Data("not-a-p12".utf8)
        XCTAssertThrowsError(try PKCS12Parser.parse(data: junk, password: "x"))
    }
}

final class InMemoryCertificateStoreTests: XCTestCase {
    func testStoreListDelete() async throws {
        let store = InMemoryCertificateStore()
        let cert = CredentialFixtures.makeSecCertificate()
        let metadata = try CertificateMetadataExtractor.extract(from: cert)

        let identity = await store.store(metadata: metadata)
        XCTAssertEqual(identity.fingerprintSHA256, CredentialFixtures.expectedFingerprint)

        let listed = try await store.listIdentities()
        XCTAssertEqual(listed.count, 1)

        let duplicate = await store.store(metadata: metadata)
        XCTAssertEqual(duplicate.id, identity.id)

        try await store.deleteIdentity(id: identity.id)
        let after = try await store.listIdentities()
        XCTAssertTrue(after.isEmpty)
    }
}
