import XCTest
@testable import SignFlow

final class SigningOptionsTests: XCTestCase {
    func testPPQProtectionAppendsSuffix() {
        var options = SigningOptions()
        options.ppqProtection = true
        options.ppqString = "abc123"
        XCTAssertEqual(options.resolvedIdentifier(for: "com.example.app"), "com.example.app.abc123")
    }

    func testIdentifierRulesTakePrecedence() {
        var options = SigningOptions()
        options.ppqProtection = true
        options.ppqString = "abc123"
        options.identifierRules = ["com.example.app": "com.signed.app"]
        XCTAssertEqual(options.resolvedIdentifier(for: "com.example.app"), "com.signed.app")
    }

    func testDisplayNameRules() {
        var options = SigningOptions()
        options.displayNameRules = ["Old": "New"]
        XCTAssertEqual(options.resolvedDisplayName(for: "Old"), "New")
        XCTAssertNil(options.resolvedDisplayName(for: "Other"))
    }
}

final class LibraryStoreTests: XCTestCase {
    func testSaveListAndDelete() async throws {
        let store = LibraryStore()
        let record = LibraryAppRecord(
            id: UUID(),
            kind: .imported,
            displayName: "Demo",
            bundleIdentifier: "com.demo.app",
            version: "1.0",
            buildNumber: "1",
            minimumOSVersion: "17.0",
            originalFilename: "demo.ipa",
            filePath: NSTemporaryDirectory() + "signflow-demo-\(UUID().uuidString).ipa",
            sha256: String(repeating: "a", count: 64),
            byteSize: 10,
            sourceURLString: nil,
            sourceName: nil,
            iconRelativePath: nil,
            profileTypeRaw: nil,
            importedAt: Date(),
            signedAt: nil,
            expiresAt: nil
        )
        FileManager.default.createFile(atPath: record.filePath, contents: Data("ipa".utf8))
        try await store.save(record)
        let listed = try await store.listApps()
        XCTAssertTrue(listed.contains(where: { $0.id == record.id }))
        try await store.delete(ids: [record.id])
        let after = try await store.listApps()
        XCTAssertFalse(after.contains(where: { $0.id == record.id }))
    }
}

final class SourceStoreTests: XCTestCase {
    func testAddAndListSources() async throws {
        let store = SourceStore()
        try await store.clearAll()
        let source = AppSource(name: "Demo Source", url: URL(string: "https://example.com/apps.json")!)
        try await store.addSource(source)
        let listed = try await store.listSources()
        XCTAssertTrue(listed.contains(where: { $0.url == source.url }))
        try await store.clearAll()
    }
}

final class InstallationEligibilityDevelopmentOTATests: XCTestCase {
    func testDevelopmentUsesHostedOTA() {
        let eligibility = InstallationEligibilityEvaluator.evaluate(profileType: .development, accountPlan: .free)
        guard case .hostedOTA = eligibility else {
            return XCTFail("Expected hosted OTA for development profiles")
        }
    }
}
