import XCTest
@testable import SignFlow

final class PlistParserTests: XCTestCase {
    var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    func testValidInfoPlist() throws {
        let plist: [String: Any] = [
            "CFBundleDisplayName": "My App",
            "CFBundleIdentifier": "com.test.myapp",
            "CFBundleShortVersionString": "2.1",
            "CFBundleVersion": "100",
            "CFBundleExecutable": "MyApp",
            "MinimumOSVersion": "17.0"
        ]
        let url = tempDir.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)

        let info = try PlistParser.parseInfoPlist(at: url)
        XCTAssertEqual(info.displayName, "My App")
        XCTAssertEqual(info.bundleIdentifier, "com.test.myapp")
        XCTAssertEqual(info.version, "2.1")
        XCTAssertEqual(info.buildNumber, "100")
        XCTAssertEqual(info.executableName, "MyApp")
        XCTAssertEqual(info.minimumOSVersion, "17.0")
    }

    func testMissingBundleIDThrows() throws {
        let plist: [String: Any] = [
            "CFBundleExecutable": "MyApp"
        ]
        let url = tempDir.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)

        XCTAssertThrowsError(try PlistParser.parseInfoPlist(at: url))
    }

    func testMissingExecutableThrows() throws {
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.test"
        ]
        let url = tempDir.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)

        XCTAssertThrowsError(try PlistParser.parseInfoPlist(at: url))
    }

    func testMissingFileThrows() {
        let url = tempDir.appendingPathComponent("doesnotexist.plist")
        XCTAssertThrowsError(try PlistParser.parseInfoPlist(at: url))
    }

    func testFallbackDisplayName() throws {
        let plist: [String: Any] = [
            "CFBundleIdentifier": "com.test.noname",
            "CFBundleExecutable": "Exec"
        ]
        let url = tempDir.appendingPathComponent("Info.plist")
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url)

        let info = try PlistParser.parseInfoPlist(at: url)
        XCTAssertEqual(info.displayName, "com.test.noname")
    }
}
