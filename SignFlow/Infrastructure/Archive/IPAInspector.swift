import Foundation
import OSLog

final class IPAInspector: IPAInspecting, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "IPAInspector")

    func inspect(extractedPayloadURL: URL) async throws -> AppPackage {
        try Task.checkCancellation()

        let payloadURL = try locatePayload(in: extractedPayloadURL)
        let appBundleURL = try locatePrimaryApp(in: payloadURL)

        let infoPlistURL = appBundleURL.appendingPathComponent("Info.plist")
        let appInfo = try PlistParser.parseInfoPlist(at: infoPlistURL)

        let executableURL = appBundleURL.appendingPathComponent(appInfo.executableName)
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            throw SignFlowError.missingExecutable(name: appInfo.executableName)
        }

        try Task.checkCancellation()

        let architectures: [MachOArchitecture]
        do {
            architectures = try MachOArchitectureReader.readArchitectures(at: executableURL)
        } catch {
            architectures = [.unknown]
        }

        let nestedBundles = discoverNestedBundles(
            in: appBundleURL,
            parentBundleID: appInfo.bundleIdentifier
        )

        let hasEmbeddedProfile = FileManager.default.fileExists(
            atPath: appBundleURL.appendingPathComponent("embedded.mobileprovision").path
        )

        let signatureStatus = checkSignatureStatus(appBundle: appBundleURL)

        var warnings: [ValidationIssue] = []

        if architectures.contains(.unknown) {
            warnings.append(ValidationIssue(
                severity: .warning,
                code: "UNKNOWN_ARCH",
                title: "Unknown Architecture",
                explanation: "The executable contains an unrecognized CPU architecture."
            ))
        }

        if !hasEmbeddedProfile {
            warnings.append(ValidationIssue(
                severity: .info,
                code: "NO_EMBEDDED_PROFILE",
                title: "No Embedded Profile",
                explanation: "The app does not contain an embedded.mobileprovision file."
            ))
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: appBundleURL.path)
        let fileSize = attrs[.size] as? UInt64 ?? 0

        Self.logger.info("Inspected app: \(appInfo.displayName, privacy: .public), bundle: \(appInfo.bundleIdentifier, privacy: .public)")

        return AppPackage(
            id: UUID(),
            sourceURL: extractedPayloadURL,
            originalFilename: extractedPayloadURL.lastPathComponent,
            sha256: "",
            fileSize: fileSize,
            applicationBundleURL: appBundleURL,
            displayName: appInfo.displayName,
            executableName: appInfo.executableName,
            primaryBundleIdentifier: appInfo.bundleIdentifier,
            version: appInfo.version,
            buildNumber: appInfo.buildNumber,
            minimumOSVersion: appInfo.minimumOSVersion,
            architectures: architectures,
            nestedBundles: nestedBundles,
            embeddedProvisioningProfile: hasEmbeddedProfile,
            requestedEntitlements: nil,
            inspectionWarnings: warnings,
            existingSignatureStatus: signatureStatus
        )
    }

    // MARK: - Payload discovery

    private func locatePayload(in extractedRoot: URL) throws -> URL {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: extractedRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let payloadDirs = contents.filter { $0.lastPathComponent == "Payload" }

        if payloadDirs.isEmpty {
            throw SignFlowError.missingPayloadDirectory
        }
        if payloadDirs.count > 1 {
            throw SignFlowError.multiplePayloadDirectories
        }
        return payloadDirs[0]
    }

    private func locatePrimaryApp(in payloadURL: URL) throws -> URL {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: payloadURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let appBundles = contents.filter { $0.pathExtension == "app" }

        if appBundles.isEmpty {
            throw SignFlowError.missingPrimaryApplication
        }
        if appBundles.count > 1 {
            throw SignFlowError.multiplePrimaryApplications(count: appBundles.count)
        }
        return appBundles[0]
    }

    // MARK: - Nested bundle discovery

    private func discoverNestedBundles(in appURL: URL, parentBundleID: String) -> [NestedBundle] {
        var bundles: [NestedBundle] = []
        let fm = FileManager.default

        // Frameworks
        let frameworksURL = appURL.appendingPathComponent("Frameworks")
        if let items = try? fm.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for item in items {
                if item.pathExtension == "framework" {
                    bundles.append(makeNestedBundle(
                        url: item, type: .framework, appURL: appURL, parentBundleID: parentBundleID
                    ))
                } else if item.pathExtension == "dylib" || MachOArchitectureReader.isMachO(at: item) {
                    bundles.append(makeNestedBundle(
                        url: item, type: .dynamicLibrary, appURL: appURL, parentBundleID: parentBundleID
                    ))
                }
            }
        }

        // PlugIns (app extensions)
        let plugInsURL = appURL.appendingPathComponent("PlugIns")
        if let items = try? fm.contentsOfDirectory(at: plugInsURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for item in items where item.pathExtension == "appex" {
                bundles.append(makeNestedBundle(
                    url: item, type: .appExtension, appURL: appURL, parentBundleID: parentBundleID
                ))
            }
        }

        // Watch
        let watchURL = appURL.appendingPathComponent("Watch")
        if let items = try? fm.contentsOfDirectory(at: watchURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for item in items where item.pathExtension == "app" {
                bundles.append(makeNestedBundle(
                    url: item, type: .watchApp, appURL: appURL, parentBundleID: parentBundleID
                ))
            }
        }

        return bundles
    }

    private func makeNestedBundle(url: URL, type: NestedBundleType, appURL: URL, parentBundleID: String) -> NestedBundle {
        let relativePath = url.path.replacingOccurrences(of: appURL.path + "/", with: "")

        var bundleID: String?
        var execName: String?
        var version: String?

        let infoPlist = url.appendingPathComponent("Info.plist")
        if let info = try? PlistParser.parseInfoPlist(at: infoPlist) {
            bundleID = info.bundleIdentifier
            execName = info.executableName
            version = info.version
        }

        return NestedBundle(
            id: UUID(),
            type: type,
            relativePath: relativePath,
            bundleIdentifier: bundleID ?? url.deletingPathExtension().lastPathComponent,
            executableName: execName,
            version: version,
            parentBundleIdentifier: parentBundleID,
            nestedComponents: []
        )
    }

    // MARK: - Signature status

    private func checkSignatureStatus(appBundle: URL) -> SignatureStatus {
        let codeSignatureDir = appBundle.appendingPathComponent("_CodeSignature")
        let codeResourcesFile = codeSignatureDir.appendingPathComponent("CodeResources")

        if FileManager.default.fileExists(atPath: codeResourcesFile.path) {
            return .signed
        } else if FileManager.default.fileExists(atPath: codeSignatureDir.path) {
            return .unknown
        } else {
            return .unsigned
        }
    }
}
