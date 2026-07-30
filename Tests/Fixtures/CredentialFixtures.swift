import Foundation
import Security
@testable import SignFlow

enum CredentialFixtures {
    /// TEST ONLY — synthetic self-signed P12. Password: `testpassword`
    static let p12Password = "testpassword"
    static let expectedFingerprint = "0c78e75e66f3797b2b16b7b84455db0d18c325d0da18f748039c427ecc05c34c"
    static let expectedTeamHint = "TEAMTEST1"

    static var p12URL: URL {
        if let bundled = Bundle(for: BundleToken.self).url(forResource: "TestIdentity", withExtension: "p12") {
            return bundled
        }
        return fixturesDirectory.appendingPathComponent("TestIdentity.p12")
    }

    static var certificateDERURL: URL {
        if let bundled = Bundle(for: BundleToken.self).url(forResource: "TestIdentity", withExtension: "cer") {
            return bundled
        }
        return fixturesDirectory.appendingPathComponent("TestIdentity.cer")
    }

    private static var fixturesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
    }

    static var certificateDER: Data {
        try! Data(contentsOf: certificateDERURL)
    }

    static func makeSecCertificate() -> SecCertificate {
        SecCertificateCreateWithData(nil, certificateDER as CFData)!
    }

    /// Synthetic mobileprovision-like file: wrapper around an XML plist.
    static func makeSyntheticProfileData(
        name: String = "SignFlow Test Profile",
        uuid: String = "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
        teamID: String = "TEAMTEST1",
        appID: String = "TEAMTEST1.com.test.app",
        getTaskAllow: Bool = true,
        devices: [String]? = ["00008030-001A69661A89801C"],
        provisionsAllDevices: Bool = false,
        expiration: Date = Date().addingTimeInterval(86400 * 90),
        certificateDER: Data? = nil
    ) throws -> Data {
        let certData = certificateDER ?? self.certificateDER

        var plist: [String: Any] = [
            "Name": name,
            "UUID": uuid,
            "TeamIdentifier": [teamID],
            "ApplicationIdentifierPrefix": [teamID],
            "CreationDate": Date().addingTimeInterval(-86400),
            "ExpirationDate": expiration,
            "Platform": ["iOS"],
            "AppIDName": "Test App",
            "Entitlements": [
                "application-identifier": appID,
                "com.apple.developer.team-identifier": teamID,
                "get-task-allow": getTaskAllow,
                "keychain-access-groups": ["\(teamID).*"]
            ] as [String: Any],
            "DeveloperCertificates": [certData]
        ]

        if provisionsAllDevices {
            plist["ProvisionsAllDevices"] = true
        } else if let devices {
            plist["ProvisionedDevices"] = devices
        }

        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)

        var wrapped = Data("fake-cms-header".utf8)
        wrapped.append(plistData)
        wrapped.append(Data("fake-cms-trailer".utf8))
        return wrapped
    }

    private final class BundleToken {}
}
