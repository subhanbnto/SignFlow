import Foundation
import ZIPFoundation
@testable import SignFlow

enum TestFixtures {
    static let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SignFlowTests-\(UUID().uuidString)")

    static func setUp() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    static func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Minimal valid IPA structure

    /// Creates a minimal valid IPA (zip) containing Payload/TestApp.app/Info.plist and a fake executable
    static func createMinimalIPA(
        bundleID: String = "com.test.app",
        displayName: String = "Test App",
        executableName: String = "TestApp",
        at directory: URL? = nil
    ) throws -> URL {
        let dir = directory ?? tempDir
        let ipaURL = dir.appendingPathComponent("TestApp.ipa")

        let workDir = dir.appendingPathComponent("ipa-work-\(UUID().uuidString)")
        let payloadDir = workDir.appendingPathComponent("Payload")
        let appDir = payloadDir.appendingPathComponent("TestApp.app")
        let fm = FileManager.default

        try fm.createDirectory(at: appDir, withIntermediateDirectories: true)

        // Info.plist
        let plist: [String: Any] = [
            "CFBundleDisplayName": displayName,
            "CFBundleName": displayName,
            "CFBundleIdentifier": bundleID,
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "42",
            "CFBundleExecutable": executableName,
            "MinimumOSVersion": "17.0"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try plistData.write(to: appDir.appendingPathComponent("Info.plist"))

        // Fake Mach-O executable (thin arm64)
        try createFakeMachO(at: appDir.appendingPathComponent(executableName))

        // Create ZIP
        try createZIP(from: workDir, to: ipaURL)

        try? fm.removeItem(at: workDir)

        return ipaURL
    }

    /// Creates a fake Mach-O thin arm64 binary (just the header, enough for detection)
    static func createFakeMachO(at url: URL) throws {
        var data = Data()
        // MH_MAGIC_64 = 0xFEEDFACF
        var magic: UInt32 = 0xFEEDFACF
        data.append(Data(bytes: &magic, count: 4))
        // CPU_TYPE_ARM64 = 0x0100000C
        var cpuType: Int32 = 0x0100000C
        data.append(Data(bytes: &cpuType, count: 4))
        // CPU_SUBTYPE_ARM64_ALL = 0
        var cpuSubtype: Int32 = 0
        data.append(Data(bytes: &cpuSubtype, count: 4))
        // filetype, ncmds, sizeofcmds, flags, reserved (fill with zeros)
        let padding = Data(count: 20)
        data.append(padding)
        try data.write(to: url)
    }

    /// Creates a ZIP file from a directory using ZIPFoundation
    static func createZIP(from sourceDir: URL, to zipURL: URL) throws {
        try FileManager.default.zipItem(at: sourceDir, to: zipURL)
    }

    // MARK: - Malformed IPAs

    static func createNonZipFile(at directory: URL? = nil) throws -> URL {
        let dir = directory ?? tempDir
        let url = dir.appendingPathComponent("notanipa.ipa")
        try "This is not a ZIP file".data(using: .utf8)!.write(to: url)
        return url
    }

    static func createIPAMissingPayload(at directory: URL? = nil) throws -> URL {
        let dir = directory ?? tempDir
        let ipaURL = dir.appendingPathComponent("nopayload.ipa")
        let workDir = dir.appendingPathComponent("nopayload-work-\(UUID().uuidString)")
        let randomDir = workDir.appendingPathComponent("NotPayload")
        try FileManager.default.createDirectory(at: randomDir, withIntermediateDirectories: true)
        try "hello".data(using: .utf8)!.write(to: randomDir.appendingPathComponent("file.txt"))
        try createZIP(from: workDir, to: ipaURL)
        try? FileManager.default.removeItem(at: workDir)
        return ipaURL
    }

    static func createIPAMissingApp(at directory: URL? = nil) throws -> URL {
        let dir = directory ?? tempDir
        let ipaURL = dir.appendingPathComponent("noapp.ipa")
        let workDir = dir.appendingPathComponent("noapp-work-\(UUID().uuidString)")
        let payloadDir = workDir.appendingPathComponent("Payload")
        try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)
        try "hello".data(using: .utf8)!.write(to: payloadDir.appendingPathComponent("file.txt"))
        try createZIP(from: workDir, to: ipaURL)
        try? FileManager.default.removeItem(at: workDir)
        return ipaURL
    }

    static func createIPAWithExtension(at directory: URL? = nil) throws -> URL {
        let dir = directory ?? tempDir
        let ipaURL = dir.appendingPathComponent("WithExtension.ipa")
        let workDir = dir.appendingPathComponent("ext-work-\(UUID().uuidString)")
        let appDir = workDir.appendingPathComponent("Payload/TestApp.app")
        let extDir = appDir.appendingPathComponent("PlugIns/ShareExtension.appex")
        let fwDir = appDir.appendingPathComponent("Frameworks/SomeFramework.framework")
        let fm = FileManager.default

        try fm.createDirectory(at: extDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: fwDir, withIntermediateDirectories: true)

        // Main app
        let mainPlist: [String: Any] = [
            "CFBundleDisplayName": "TestApp",
            "CFBundleIdentifier": "com.test.app",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "CFBundleExecutable": "TestApp",
            "MinimumOSVersion": "17.0"
        ]
        try PropertyListSerialization.data(fromPropertyList: mainPlist, format: .xml, options: 0)
            .write(to: appDir.appendingPathComponent("Info.plist"))
        try createFakeMachO(at: appDir.appendingPathComponent("TestApp"))

        // Extension
        let extPlist: [String: Any] = [
            "CFBundleDisplayName": "Share Extension",
            "CFBundleIdentifier": "com.test.app.share",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "CFBundleExecutable": "ShareExtension",
        ]
        try PropertyListSerialization.data(fromPropertyList: extPlist, format: .xml, options: 0)
            .write(to: extDir.appendingPathComponent("Info.plist"))
        try createFakeMachO(at: extDir.appendingPathComponent("ShareExtension"))

        // Framework
        let fwPlist: [String: Any] = [
            "CFBundleIdentifier": "com.test.framework",
            "CFBundleExecutable": "SomeFramework",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
        ]
        try PropertyListSerialization.data(fromPropertyList: fwPlist, format: .xml, options: 0)
            .write(to: fwDir.appendingPathComponent("Info.plist"))
        try createFakeMachO(at: fwDir.appendingPathComponent("SomeFramework"))

        try createZIP(from: workDir, to: ipaURL)
        try? fm.removeItem(at: workDir)
        return ipaURL
    }
}
