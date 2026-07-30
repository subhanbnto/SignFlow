import XCTest
@testable import SignFlow

final class CertificateProfileMatcherTests: XCTestCase {
    func testMatchingByFingerprint() async throws {
        let data = try CredentialFixtures.makeSyntheticProfileData()
        let profile = try await ProvisioningProfileParser().parse(profileData: data)

        let matching = SigningIdentity(
            id: UUID(),
            displayName: "Match",
            commonName: "Match",
            issuer: "Test",
            teamIdentifier: "TEAMTEST1",
            serialNumber: "1",
            certificateType: .development,
            validFrom: Date().addingTimeInterval(-1000),
            expiresAt: Date().addingTimeInterval(10000),
            fingerprintSHA256: CredentialFixtures.expectedFingerprint,
            keychainReference: Data([0x01]),
            hasPrivateKey: true,
            importedAt: Date()
        )

        let nonMatching = SigningIdentity(
            id: UUID(),
            displayName: "Other",
            commonName: "Other",
            issuer: "Test",
            teamIdentifier: "OTHERTEAM1",
            serialNumber: "2",
            certificateType: .development,
            validFrom: Date().addingTimeInterval(-1000),
            expiresAt: Date().addingTimeInterval(10000),
            fingerprintSHA256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            keychainReference: Data([0x02]),
            hasPrivateKey: true,
            importedAt: Date()
        )

        let matches = CertificateProfileMatcher.matchingIdentities([matching, nonMatching], in: profile)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.id, matching.id)

        XCTAssertTrue(CertificateProfileMatcher.fingerprintMatches(matching, profile: profile))
        XCTAssertFalse(CertificateProfileMatcher.fingerprintMatches(nonMatching, profile: profile))

        let profiles = CertificateProfileMatcher.matchingProfiles([profile], for: matching)
        XCTAssertEqual(profiles.count, 1)
    }
}
