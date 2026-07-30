import XCTest
@testable import SignFlow

final class SHA256HasherTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testKnownHash() async throws {
        let url = tempDir.appendingPathComponent("test.txt")
        try "hello".data(using: .utf8)!.write(to: url)

        let hash = try await SHA256Hasher.hash(fileAt: url)
        // SHA-256 of "hello"
        XCTAssertEqual(hash, "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    func testEmptyFileHash() async throws {
        let url = tempDir.appendingPathComponent("empty.txt")
        try Data().write(to: url)

        let hash = try await SHA256Hasher.hash(fileAt: url)
        // SHA-256 of empty input
        XCTAssertEqual(hash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }
}
