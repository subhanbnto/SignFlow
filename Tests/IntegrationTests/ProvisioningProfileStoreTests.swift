import XCTest
@testable import SignFlow

final class ProvisioningProfileStoreTests: XCTestCase {
    var store: ProvisioningProfileStore!
    var parser: ProvisioningProfileParser!

    override func setUp() async throws {
        store = ProvisioningProfileStore()
        parser = ProvisioningProfileParser()
        // Clean prior test profiles
        let existing = try await store.listProfiles()
        for profile in existing where profile.uuid.hasPrefix("AAAAAAAA") || profile.name.contains("SignFlow Test") {
            try await store.deleteProfile(id: profile.id)
        }
    }

    func testSaveListDelete() async throws {
        let data = try CredentialFixtures.makeSyntheticProfileData()
        let parsed = try await parser.parse(profileData: data)
        let saved = try await store.save(parsed, originalData: data)

        XCTAssertNotNil(saved.filePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: saved.filePath!))

        let listed = try await store.listProfiles()
        XCTAssertTrue(listed.contains { $0.uuid == saved.uuid })
        let listedProfile = try XCTUnwrap(listed.first { $0.uuid == saved.uuid })
        XCTAssertTrue(FileManager.default.fileExists(atPath: listedProfile.filePath!))

        let fileData = try await store.profileFileData(for: saved.id)
        XCTAssertEqual(fileData, data)

        try await store.deleteProfile(id: saved.id)
        let after = try await store.listProfiles()
        XCTAssertFalse(after.contains { $0.id == saved.id })
        XCTAssertFalse(FileManager.default.fileExists(atPath: saved.filePath!))
    }

    func testCanonicalPathSurvivesStaleAbsoluteMetadata() async throws {
        let data = try CredentialFixtures.makeSyntheticProfileData()
        let parsed = try await parser.parse(profileData: data)
        let saved = try await store.save(parsed, originalData: data)

        let canonical = try ProvisioningProfileStore.canonicalFileURL(forUUID: saved.uuid)
        XCTAssertTrue(FileManager.default.fileExists(atPath: canonical.path))

        // Simulate stale metadata that points at a non-existent absolute path.
        let stale = ProvisioningProfile(
            id: saved.id,
            name: saved.name,
            uuid: saved.uuid,
            teamIdentifiers: saved.teamIdentifiers,
            applicationIdentifierPrefix: saved.applicationIdentifierPrefix,
            creationDate: saved.creationDate,
            expirationDate: saved.expirationDate,
            supportedPlatforms: saved.supportedPlatforms,
            provisionedDevices: saved.provisionedDevices,
            provisionsAllDevices: saved.provisionsAllDevices,
            entitlements: saved.entitlements,
            developerCertificateFingerprints: saved.developerCertificateFingerprints,
            profileType: saved.profileType,
            appIDName: saved.appIDName,
            applicationIdentifier: saved.applicationIdentifier,
            importedAt: saved.importedAt,
            filePath: "/tmp/does-not-exist/\(saved.uuid).mobileprovision"
        )

        // Re-save metadata with a stale path while leaving the real file in place.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let metadataURL = appSupport
            .appendingPathComponent("SignFlow", isDirectory: true)
            .appendingPathComponent("provisioning-profiles.json")
        let encoded = try JSONEncoder().encode([stale])
        try encoded.write(to: metadataURL, options: .atomic)

        let listed = try await store.listProfiles()
        let healed = try XCTUnwrap(listed.first { $0.uuid == saved.uuid })
        XCTAssertEqual(healed.filePath, canonical.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: healed.filePath!))

        try await store.deleteProfile(id: saved.id)
    }
}
