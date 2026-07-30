import XCTest
import Security
@testable import SignFlow

final class CertificateFingerprintTests: XCTestCase {
    func testKnownFingerprint() {
        let fingerprint = CertificateFingerprint.sha256(of: CredentialFixtures.certificateDER)
        XCTAssertEqual(fingerprint, CredentialFixtures.expectedFingerprint)
    }

    func testSecCertificateFingerprint() {
        let cert = CredentialFixtures.makeSecCertificate()
        let fingerprint = CertificateFingerprint.sha256(of: cert)
        XCTAssertEqual(fingerprint, CredentialFixtures.expectedFingerprint)
    }
}
