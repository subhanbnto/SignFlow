import XCTest
@testable import SignFlow

final class SignFlowErrorM2Tests: XCTestCase {
    func testM2ErrorsHaveUserFacingCopy() {
        let errors: [SignFlowError] = [
            .invalidP12(detail: "bad"),
            .incorrectP12Password,
            .missingSigningIdentity,
            .missingPrivateKey,
            .expiredCertificate(name: "Test", expiredAt: Date()),
            .invalidCertificate(detail: "bad"),
            .malformedProvisioningProfile(detail: "bad"),
            .expiredProvisioningProfile(name: "Prof", expiredAt: Date()),
            .certificateNotIncludedInProfile,
            .teamIdentifierMismatch(expected: "A", actual: "B"),
            .appIdentifierMismatch(expected: "x", actual: "y"),
            .deviceNotProvisioned,
        ]

        for error in errors {
            XCTAssertFalse(error.title.isEmpty)
            XCTAssertFalse(error.explanation.isEmpty)
            XCTAssertFalse(error.suggestedResolution.isEmpty)
            XCTAssertFalse(error.explanation.contains("not yet implemented"))
        }
    }
}
