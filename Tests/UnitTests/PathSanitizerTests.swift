import XCTest
@testable import SignFlow

final class PathSanitizerTests: XCTestCase {
    let root = URL(fileURLWithPath: "/tmp/test-root")

    func testValidPathSucceeds() throws {
        let result = try PathSanitizer.validate(entryPath: "Payload/App.app/Info.plist", relativeTo: root)
        XCTAssertTrue(result.path.hasPrefix(root.path))
    }

    func testEmptyPathThrows() {
        XCTAssertThrowsError(try PathSanitizer.validate(entryPath: "", relativeTo: root))
    }

    func testZipSlipPathThrows() {
        XCTAssertThrowsError(try PathSanitizer.validate(entryPath: "../../../etc/passwd", relativeTo: root))
    }

    func testZipSlipMidPathThrows() {
        XCTAssertThrowsError(try PathSanitizer.validate(entryPath: "Payload/../../outside", relativeTo: root))
    }

    func testDotSegmentIsIgnored() throws {
        let result = try PathSanitizer.validate(entryPath: "Payload/./file.txt", relativeTo: root)
        XCTAssertTrue(result.path.hasPrefix(root.path))
    }

    func testDepthCalculation() {
        let child = root.appendingPathComponent("a/b/c")
        XCTAssertEqual(PathSanitizer.depthOf(child, relativeTo: root), 3)
    }
}
