import Foundation
import OSLog

final class ProvisioningProfileParser: ProvisioningProfileParsing, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "ProfileParser")

    func parse(profileURL: URL) async throws -> ProvisioningProfile {
        let accessing = profileURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { profileURL.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: profileURL)
        return try await parse(profileData: data)
    }

    func parse(profileData: Data) async throws -> ProvisioningProfile {
        try Task.checkCancellation()

        let plistData = try extractPlist(from: profileData)
        guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw SignFlowError.malformedProvisioningProfile(detail: "Profile payload is not a dictionary.")
        }

        return try buildProfile(from: plist)
    }

    // MARK: - CMS / plist extraction

    /// mobileprovision files are CMS-signed plists. Extract the embedded plist by scanning for known markers.
    func extractPlist(from data: Data) throws -> Data {
        return try extractPlistByScanning(data)
    }

    private func extractPlistByScanning(_ data: Data) throws -> Data {
        // XML plist
        if let xmlStart = data.range(of: Data("<?xml".utf8)),
           let xmlEnd = data.range(of: Data("</plist>".utf8), options: [], in: xmlStart.lowerBound..<data.endIndex) {
            return data.subdata(in: xmlStart.lowerBound..<xmlEnd.upperBound)
        }

        // Binary plist
        if let binStart = data.range(of: Data("bplist00".utf8)) {
            // Find end by attempting to parse progressively isn't needed —
            // PropertyListSerialization will read what it needs from the start.
            return data.subdata(in: binStart.lowerBound..<data.endIndex)
        }

        throw SignFlowError.malformedProvisioningProfile(detail: "Could not locate plist content in profile.")
    }

    // MARK: - Model building

    private func buildProfile(from plist: [String: Any]) throws -> ProvisioningProfile {
        guard let name = plist["Name"] as? String else {
            throw SignFlowError.malformedProvisioningProfile(detail: "Missing Name.")
        }
        guard let uuid = plist["UUID"] as? String else {
            throw SignFlowError.malformedProvisioningProfile(detail: "Missing UUID.")
        }
        guard let expirationDate = plist["ExpirationDate"] as? Date else {
            throw SignFlowError.malformedProvisioningProfile(detail: "Missing ExpirationDate.")
        }

        let teamIDs = plist["TeamIdentifier"] as? [String] ?? []
        let appIDPrefix = plist["ApplicationIdentifierPrefix"] as? [String] ?? teamIDs
        let creationDate = plist["CreationDate"] as? Date ?? Date.distantPast
        let platforms = (plist["Platform"] as? [String]) ?? ["iOS"]
        let devices = plist["ProvisionedDevices"] as? [String]
        let provisionsAll = plist["ProvisionsAllDevices"] as? Bool ?? false
        let appIDName = plist["AppIDName"] as? String

        let rawEntitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        let entitlements = flattenEntitlements(rawEntitlements)
        let applicationIdentifier = rawEntitlements["application-identifier"] as? String

        let fingerprints = extractCertificateFingerprints(from: plist)
        let profileType = classifyProfile(
            provisionsAllDevices: provisionsAll,
            hasDevices: devices != nil && !(devices?.isEmpty ?? true),
            entitlements: rawEntitlements,
            getTaskAllow: rawEntitlements["get-task-allow"] as? Bool ?? false
        )

        Self.logger.info("Parsed profile \(uuid, privacy: .public) type=\(profileType.rawValue, privacy: .public)")

        return ProvisioningProfile(
            id: UUID(),
            name: name,
            uuid: uuid,
            teamIdentifiers: teamIDs,
            applicationIdentifierPrefix: appIDPrefix,
            creationDate: creationDate,
            expirationDate: expirationDate,
            supportedPlatforms: platforms,
            provisionedDevices: devices,
            provisionsAllDevices: provisionsAll,
            entitlements: entitlements,
            developerCertificateFingerprints: fingerprints,
            profileType: profileType,
            appIDName: appIDName,
            applicationIdentifier: applicationIdentifier,
            importedAt: Date(),
            filePath: nil
        )
    }

    private func flattenEntitlements(_ entitlements: [String: Any]) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in entitlements {
            if let string = value as? String {
                result[key] = string
            } else if let bool = value as? Bool {
                result[key] = bool ? "true" : "false"
            } else if let array = value as? [Any] {
                result[key] = array.map { "\($0)" }.joined(separator: ", ")
            } else if let data = try? JSONSerialization.data(withJSONObject: value),
                      let string = String(data: data, encoding: .utf8) {
                result[key] = string
            } else {
                result[key] = "\(value)"
            }
        }
        return result
    }

    private func extractCertificateFingerprints(from plist: [String: Any]) -> [String] {
        guard let certs = plist["DeveloperCertificates"] as? [Data] else { return [] }
        return certs.map { CertificateFingerprint.sha256(of: $0) }
    }

    func classifyProfile(
        provisionsAllDevices: Bool,
        hasDevices: Bool,
        entitlements: [String: Any],
        getTaskAllow: Bool
    ) -> ProfileType {
        if provisionsAllDevices {
            return .enterprise
        }
        if getTaskAllow {
            return .development
        }
        if hasDevices {
            return .adHoc
        }
        // No devices, get-task-allow false → typically App Store
        return .appStore
    }
}
