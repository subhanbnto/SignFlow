import Foundation

enum PlistParser {
    struct AppInfo: Sendable {
        let displayName: String
        let bundleName: String
        let bundleIdentifier: String
        let version: String
        let buildNumber: String
        let executableName: String
        let minimumOSVersion: String
    }

    static func parseInfoPlist(at url: URL) throws -> AppInfo {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SignFlowError.malformedInfoPlist(detail: "Info.plist not found.")
        }

        guard let data = try? Data(contentsOf: url) else {
            throw SignFlowError.malformedInfoPlist(detail: "Could not read Info.plist data.")
        }

        guard let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw SignFlowError.malformedInfoPlist(detail: "Info.plist is not a valid property list dictionary.")
        }

        guard let bundleIdentifier = plist["CFBundleIdentifier"] as? String, !bundleIdentifier.isEmpty else {
            throw SignFlowError.malformedInfoPlist(detail: "Missing CFBundleIdentifier.")
        }

        guard let executableName = plist["CFBundleExecutable"] as? String, !executableName.isEmpty else {
            throw SignFlowError.malformedInfoPlist(detail: "Missing CFBundleExecutable.")
        }

        let displayName = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? bundleIdentifier
        let bundleName = plist["CFBundleName"] as? String ?? displayName
        let version = plist["CFBundleShortVersionString"] as? String ?? "0.0"
        let buildNumber = plist["CFBundleVersion"] as? String ?? "0"
        let minimumOS = plist["MinimumOSVersion"] as? String ?? "Unknown"

        return AppInfo(
            displayName: displayName,
            bundleName: bundleName,
            bundleIdentifier: bundleIdentifier,
            version: version,
            buildNumber: buildNumber,
            executableName: executableName,
            minimumOSVersion: minimumOS
        )
    }

    static func readEntitlements(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }
}
