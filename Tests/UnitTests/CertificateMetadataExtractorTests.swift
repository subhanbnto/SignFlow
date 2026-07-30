import XCTest
import Security
@testable import SignFlow

final class CertificateMetadataExtractorTests: XCTestCase {
    func testExtractsCommonNameAndTeam() throws {
        let cert = CredentialFixtures.makeSecCertificate()
        let metadata = try CertificateMetadataExtractor.extract(from: cert)

        XCTAssertTrue(metadata.commonName.contains("SignFlow Test Developer"))
        XCTAssertEqual(metadata.teamIdentifier, CredentialFixtures.expectedTeamHint)
        XCTAssertEqual(metadata.fingerprintSHA256, CredentialFixtures.expectedFingerprint)
        XCTAssertFalse(metadata.serialNumber.isEmpty)
        XCTAssertNotEqual(metadata.serialNumber, "unknown")
        XCTAssertGreaterThan(metadata.expiresAt, metadata.validFrom)
        XCTAssertGreaterThan(metadata.expiresAt, Date())
    }
}
