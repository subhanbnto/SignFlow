import Foundation
import OSLog

struct AppModifier: AppModifying {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "AppModifier")

    func apply(options: SigningOptions, toAppBundle appURL: URL, displayName: String) async throws {
        try Task.checkCancellation()
        let infoURL = appURL.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw SignFlowError.malformedInfoPlist(detail: "Could not modify Info.plist.")
        }

        if options.fileSharing {
            plist["UIFileSharingEnabled"] = true
            plist["UISupportsDocumentBrowser"] = true
        }
        if options.itunesFileSharing {
            plist["UIFileSharingEnabled"] = true
        }
        if options.proMotion {
            plist["CADisableMinimumFrameDurationOnPhone"] = true
        }
        if options.gameMode {
            plist["GCSupportsGameMode"] = true
        }
        if options.ipadFullscreen {
            plist["UIRequiresFullScreen"] = false
        }
        if options.removeURLScheme {
            plist.removeValue(forKey: "CFBundleURLTypes")
        }
        if let min = options.minimumAppRequirement.versionString {
            plist["MinimumOSVersion"] = min
        }
        switch options.appAppearance {
        case .default:
            break
        case .light:
            plist["UIUserInterfaceStyle"] = "Light"
        case .dark:
            plist["UIUserInterfaceStyle"] = "Dark"
        }
        if options.enableLiquidGlass {
            plist["UIDesignRequiresCompatibility"] = false
        }
        if options.disableLiquidGlass {
            plist["UIDesignRequiresCompatibility"] = true
        }

        if options.forceLocalizeDisplayName {
            try updateLocalizedDisplayNames(displayName, in: appURL)
        }

        let out = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try out.write(to: infoURL, options: .atomic)

        if !options.removeDylibRelativePaths.isEmpty {
            for relative in options.removeDylibRelativePaths {
                let url = appURL.appendingPathComponent(relative)
                try? FileManager.default.removeItem(at: url)
            }
        }

        Self.logger.info("Applied signing options to \(appURL.lastPathComponent, privacy: .public)")
    }

    private func updateLocalizedDisplayNames(_ name: String, in appURL: URL) throws {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: appURL, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in enumerator {
            guard url.lastPathComponent == "InfoPlist.strings" else { continue }
            var strings: [String: String] = [:]
            if let data = try? Data(contentsOf: url),
               let parsed = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] {
                strings = parsed
            }
            strings["CFBundleDisplayName"] = name
            strings["CFBundleName"] = name
            let out = try PropertyListSerialization.data(fromPropertyList: strings, format: .binary, options: 0)
            try out.write(to: url, options: .atomic)
        }
    }
}
