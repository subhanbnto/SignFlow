import XCTest
@testable import SignFlow

final class ProvisioningProfileParserTests: XCTestCase {
    let parser = ProvisioningProfileParser()

    func testParseValidDevelopmentProfile() async throws {
        let data = try CredentialFixtures.makeSyntheticProfileData()
        let profile = try await parser.parse(profileData: data)

        XCTAssertEqual(profile.name, "SignFlow Test Profile")
        XCTAssertEqual(profile.uuid, "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")
        XCTAssertEqual(profile.teamIdentifier, "TEAMTEST1")
        XCTAssertEqual(profile.applicationIdentifier, "TEAMTEST1.com.test.app")
        XCTAssertEqual(profile.profileType, .development)
        XCTAssertEqual(profile.deviceCount, 1)
        XCTAssertFalse(profile.isExpired)
        XCTAssertTrue(profile.developerCertificateFingerprints.contains(CredentialFixtures.expectedFingerprint))
        XCTAssertEqual(profile.entitlements["get-task-allow"], "true")
    }

    func testClassifyAdHoc() {
        let type = parser.classifyProfile(
            provisionsAllDevices: false,
            hasDevices: true,
            entitlements: [:],
            getTaskAllow: false
        )
        XCTAssertEqual(type, .adHoc)
    }

    func testClassifyAppStore() {
        let type = parser.classifyProfile(
            provisionsAllDevices: false,
            hasDevices: false,
            entitlements: [:],
            getTaskAllow: false
        )
        XCTAssertEqual(type, .appStore)
    }

    func testClassifyEnterprise() {
        let type = parser.classifyProfile(
            provisionsAllDevices: true,
            hasDevices: false,
            entitlements: [:],
            getTaskAllow: false
        )
        XCTAssertEqual(type, .enterprise)
    }

    func testExpiredProfile() async throws {
        let data = try CredentialFixtures.makeSyntheticProfileData(
            expiration: Date().addingTimeInterval(-86400)
        )
        let profile = try await parser.parse(profileData: data)
        XCTAssertTrue(profile.isExpired)
    }

    func testMalformedProfileThrows() async {
        let junk = Data("not a profile".utf8)
        do {
            _ = try await parser.parse(profileData: junk)
            XCTFail("Should throw")
        } catch let error as SignFlowError {
            if case .malformedProvisioningProfile = error { } else {
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }

    func testMissingNameThrows() async throws {
        var plist: [String: Any] = [
            "UUID": "x",
            "ExpirationDate": Date()
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        do {
            _ = try await parser.parse(profileData: plistData)
            XCTFail("Should throw")
        } catch let error as SignFlowError {
            if case .malformedProvisioningProfile = error { } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }
}
