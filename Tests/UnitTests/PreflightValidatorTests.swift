import XCTest
@testable import SignFlow

final class BundleIdentifierRewriterTests: XCTestCase {
    let rewriter = BundleIdentifierRewriter()

    func testPrimaryAndExtensionRewrite() {
        let nested = [
            NestedBundle(
                id: UUID(), type: .appExtension,
                relativePath: "PlugIns/Share.appex",
                bundleIdentifier: "com.example.original.share",
                executableName: "Share", version: "1.0",
                parentBundleIdentifier: "com.example.original",
                nestedComponents: []
            )
        ]

        let mappings = rewriter.computeMappings(
            original: "com.example.original",
            replacement: "com.signflow.myapp",
            nestedBundles: nested
        )

        XCTAssertEqual(mappings.first?.replacement, "com.signflow.myapp")
        XCTAssertEqual(mappings[1].replacement, "com.signflow.myapp.share")
    }
}

final class EntitlementResolverTests: XCTestCase {
    let resolver = EntitlementResolver()

    func testStrictFailsOnUnsupported() {
        let result = resolver.resolve(
            requested: ["aps-environment": "development", "unknown.capability": true],
            permitted: ["aps-environment": "development", "application-identifier": "TEAM.com.app", "com.apple.developer.team-identifier": "TEAM"],
            strategy: .strict,
            bundleIdentifier: "com.app",
            teamIdentifier: "TEAM"
        )
        XCTAssertTrue(result.issues.contains { $0.severity == .fatal })
        XCTAssertTrue(result.removedKeys.contains("unknown.capability"))
    }

    func testPermittedSubsetRemovesUnsupported() {
        let result = resolver.resolve(
            requested: ["aps-environment": "development", "unknown.capability": true],
            permitted: ["aps-environment": "development", "application-identifier": "TEAM.com.app", "com.apple.developer.team-identifier": "TEAM"],
            strategy: .permittedSubset,
            bundleIdentifier: "com.app",
            teamIdentifier: "TEAM"
        )
        XCTAssertFalse(result.issues.contains { $0.severity == .fatal })
        XCTAssertNil(result.resolvedEntitlements["unknown.capability"])
        XCTAssertNotNil(result.resolvedEntitlements["aps-environment"])
    }
}

final class PreflightValidatorTests: XCTestCase {
    func testMatchingAssetsCanSign() async throws {
        let certData = CredentialFixtures.certificateDER
        let fingerprint = CertificateFingerprint.sha256(of: certData)

        let identity = SigningIdentity(
            id: UUID(),
            displayName: "Test",
            commonName: "Test",
            issuer: "Test",
            teamIdentifier: "TEAMTEST1",
            serialNumber: "1",
            certificateType: .development,
            validFrom: Date().addingTimeInterval(-1000),
            expiresAt: Date().addingTimeInterval(86400 * 100),
            fingerprintSHA256: fingerprint,
            keychainReference: Data([0x01]),
            hasPrivateKey: true,
            importedAt: Date()
        )

        let profileData = try CredentialFixtures.makeSyntheticProfileData(
            appID: "TEAMTEST1.com.test.app",
            getTaskAllow: true
        )
        let profile = try await ProvisioningProfileParser().parse(profileData: profileData)

        let package = AppPackage(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/test.ipa"),
            originalFilename: "test.ipa",
            sha256: "abc",
            fileSize: 100,
            applicationBundleURL: URL(fileURLWithPath: "/tmp/App.app"),
            displayName: "Test",
            executableName: "Test",
            primaryBundleIdentifier: "com.test.app",
            version: "1.0",
            buildNumber: "1",
            minimumOSVersion: "17.0",
            architectures: [.arm64],
            nestedBundles: [],
            embeddedProvisioningProfile: false,
            requestedEntitlements: nil,
            inspectionWarnings: [],
            existingSignatureStatus: .unsigned
        )

        let config = SigningConfiguration(
            package: package,
            identity: identity,
            profile: profile,
            requestedDisplayName: nil,
            requestedPrimaryBundleIdentifier: nil,
            entitlementStrategy: .permittedSubset,
            removeUnsupportedEntitlements: true,
            outputFilename: "out.ipa"
        )

        let report = await PreflightValidator().validate(configuration: config)
        XCTAssertTrue(report.canSign, "Issues: \(report.fatalIssues.map(\.title))")
    }

    func testMismatchedCertificateIsFatal() async throws {
        let identity = SigningIdentity(
            id: UUID(),
            displayName: "Test",
            commonName: "Test",
            issuer: "Test",
            teamIdentifier: "TEAMTEST1",
            serialNumber: "1",
            certificateType: .development,
            validFrom: Date().addingTimeInterval(-1000),
            expiresAt: Date().addingTimeInterval(86400 * 100),
            fingerprintSHA256: String(repeating: "ab", count: 32),
            keychainReference: Data([0x01]),
            hasPrivateKey: true,
            importedAt: Date()
        )

        let profileData = try CredentialFixtures.makeSyntheticProfileData()
        let profile = try await ProvisioningProfileParser().parse(profileData: profileData)

        let package = AppPackage(
            id: UUID(),
            sourceURL: URL(fileURLWithPath: "/tmp/test.ipa"),
            originalFilename: "test.ipa",
            sha256: "abc",
            fileSize: 100,
            applicationBundleURL: URL(fileURLWithPath: "/tmp/App.app"),
            displayName: "Test",
            executableName: "Test",
            primaryBundleIdentifier: "com.test.app",
            version: "1.0",
            buildNumber: "1",
            minimumOSVersion: "17.0",
            architectures: [.arm64],
            nestedBundles: [],
            embeddedProvisioningProfile: false,
            requestedEntitlements: nil,
            inspectionWarnings: [],
            existingSignatureStatus: .unsigned
        )

        let config = SigningConfiguration(
            package: package,
            identity: identity,
            profile: profile,
            requestedDisplayName: nil,
            requestedPrimaryBundleIdentifier: nil,
            entitlementStrategy: .permittedSubset,
            removeUnsupportedEntitlements: true,
            outputFilename: "out.ipa"
        )

        let report = await PreflightValidator().validate(configuration: config)
        XCTAssertFalse(report.canSign)
        XCTAssertTrue(report.fatalIssues.contains { $0.code == "CERT_NOT_IN_PROFILE" })
    }
}
