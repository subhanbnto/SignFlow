import XCTest
@testable import SignFlow

final class ExportOnlyInstallerTests: XCTestCase {
    func testDevelopmentInstallReturnsExternalShare() async throws {
        let installer = ExportOnlyInstaller()
        let request = InstallationRequest(
            ipaURL: URL(fileURLWithPath: "/tmp/demo.ipa"),
            outputSHA256: String(repeating: "a", count: 64),
            bundleIdentifier: "com.example.app",
            bundleVersion: "1.0",
            displayName: "Demo",
            profileType: .development,
            profileName: "Dev",
            outputFilename: "demo.ipa",
            byteSize: 10
        )

        let result = try await installer.install(request: request) { _ in }
        XCTAssertEqual(result.kind, .externalShare)
        XCTAssertNil(result.installURL)
    }

    func testAdHocWithoutBackendThrowsNotConfigured() async {
        let installer = ExportOnlyInstaller()
        let request = InstallationRequest(
            ipaURL: URL(fileURLWithPath: "/tmp/demo.ipa"),
            outputSHA256: String(repeating: "a", count: 64),
            bundleIdentifier: "com.example.app",
            bundleVersion: "1.0",
            displayName: "Demo",
            profileType: .adHoc,
            profileName: "AdHoc",
            outputFilename: "demo.ipa",
            byteSize: 10
        )

        do {
            _ = try await installer.install(request: request) { _ in }
            XCTFail("Expected configuration error")
        } catch let error as SignFlowError {
            guard case .installationNotConfigured = error else {
                return XCTFail("Unexpected error \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
