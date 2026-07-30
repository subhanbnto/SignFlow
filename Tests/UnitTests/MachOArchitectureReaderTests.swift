import XCTest
@testable import SignFlow

final class MachOArchitectureReaderTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testThinARM64Detection() throws {
        let url = tempDir.appendingPathComponent("arm64binary")
        try TestFixtures.createFakeMachO(at: url)
        let archs = try MachOArchitectureReader.readArchitectures(at: url)
        XCTAssertEqual(archs, [.arm64])
    }

    func testNonMachOIsNotDetected() throws {
        let url = tempDir.appendingPathComponent("textfile")
        try "Hello world".data(using: .utf8)!.write(to: url)
        XCTAssertFalse(MachOArchitectureReader.isMachO(at: url))
    }

    func testIsMachOReturnsTrueForValidBinary() throws {
        let url = tempDir.appendingPathComponent("binary")
        try TestFixtures.createFakeMachO(at: url)
        XCTAssertTrue(MachOArchitectureReader.isMachO(at: url))
    }

    func testEmptyFileThrows() throws {
        let url = tempDir.appendingPathComponent("empty")
        try Data().write(to: url)
        XCTAssertThrowsError(try MachOArchitectureReader.readArchitectures(at: url))
    }
}
