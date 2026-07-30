import XCTest
@testable import SignFlow

final class IPAInspectorTests: XCTestCase {
    var tempDir: URL!
    let extractor = SafeZIPExtractor()
    let inspector = IPAInspector()

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SignFlowIT-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testMinimalIPAInspection() async throws {
        let ipaURL = try TestFixtures.createMinimalIPA(at: tempDir)
        let extractDir = tempDir.appendingPathComponent("extract")
        _ = try await extractor.extract(archiveURL: ipaURL, to: extractDir, limits: .testing)

        // ditto --keepParent wraps in a directory named after the source folder
        let innerDir = try locatePayloadParent(in: extractDir)
        let package = try await inspector.inspect(extractedPayloadURL: innerDir)

        XCTAssertEqual(package.displayName, "Test App")
        XCTAssertEqual(package.primaryBundleIdentifier, "com.test.app")
        XCTAssertEqual(package.version, "1.0")
        XCTAssertEqual(package.buildNumber, "42")
        XCTAssertEqual(package.executableName, "TestApp")
        XCTAssertTrue(package.architectures.contains(.arm64))
        XCTAssertFalse(package.embeddedProvisioningProfile)
    }

    func testIPAWithExtensionsAndFrameworks() async throws {
        let ipaURL = try TestFixtures.createIPAWithExtension(at: tempDir)
        let extractDir = tempDir.appendingPathComponent("extract")
        _ = try await extractor.extract(archiveURL: ipaURL, to: extractDir, limits: .testing)

        let innerDir = try locatePayloadParent(in: extractDir)
        let package = try await inspector.inspect(extractedPayloadURL: innerDir)

        XCTAssertEqual(package.primaryBundleIdentifier, "com.test.app")

        let types = Set(package.nestedBundles.map(\.type))
        XCTAssertTrue(types.contains(.appExtension))
        XCTAssertTrue(types.contains(.framework))

        let extensionBundle = package.nestedBundles.first { $0.type == .appExtension }
        XCTAssertEqual(extensionBundle?.bundleIdentifier, "com.test.app.share")
    }

    func testMissingPayloadThrows() async throws {
        let ipaURL = try TestFixtures.createIPAMissingPayload(at: tempDir)
        let extractDir = tempDir.appendingPathComponent("extract")
        _ = try await extractor.extract(archiveURL: ipaURL, to: extractDir, limits: .testing)

        let innerDir = try locatePayloadParent(in: extractDir)
        do {
            _ = try await inspector.inspect(extractedPayloadURL: innerDir)
            XCTFail("Should have thrown")
        } catch let error as SignFlowError {
            if case .missingPayloadDirectory = error { } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    func testMissingAppThrows() async throws {
        let ipaURL = try TestFixtures.createIPAMissingApp(at: tempDir)
        let extractDir = tempDir.appendingPathComponent("extract")
        _ = try await extractor.extract(archiveURL: ipaURL, to: extractDir, limits: .testing)

        let innerDir = try locatePayloadParent(in: extractDir)
        do {
            _ = try await inspector.inspect(extractedPayloadURL: innerDir)
            XCTFail("Should have thrown")
        } catch let error as SignFlowError {
            if case .missingPrimaryApplication = error { } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    func testNonZipFileFailsExtraction() async throws {
        let nonZipURL = try TestFixtures.createNonZipFile(at: tempDir)
        let extractDir = tempDir.appendingPathComponent("extract")
        do {
            _ = try await extractor.extract(archiveURL: nonZipURL, to: extractDir, limits: .testing)
            XCTFail("Should have thrown")
        } catch let error as SignFlowError {
            if case .invalidIPA = error { } else {
                XCTFail("Wrong error: \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func locatePayloadParent(in extractDir: URL) throws -> URL {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)

        // ditto --keepParent creates a subdirectory; check if Payload is nested
        for item in contents {
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: item.appendingPathComponent("Payload").path, isDirectory: &isDir), isDir.boolValue {
                return item
            }
            if item.lastPathComponent == "Payload" {
                return extractDir
            }
        }
        return extractDir
    }
}
