import Foundation

struct AppPackage: Identifiable, Hashable, Sendable {
    let id: UUID
    let sourceURL: URL
    let originalFilename: String
    let sha256: String
    let fileSize: UInt64
    let applicationBundleURL: URL
    let displayName: String
    let executableName: String
    let primaryBundleIdentifier: String
    let version: String
    let buildNumber: String
    let minimumOSVersion: String
    let architectures: [MachOArchitecture]
    let nestedBundles: [NestedBundle]
    let embeddedProvisioningProfile: Bool
    let requestedEntitlements: [String: Any]?
    let inspectionWarnings: [ValidationIssue]
    let existingSignatureStatus: SignatureStatus

    static func == (lhs: AppPackage, rhs: AppPackage) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum MachOArchitecture: String, Sendable, CaseIterable {
    case arm64
    case arm64e
    case x86_64
    case armv7
    case armv7s
    case unknown
}

enum SignatureStatus: String, Sendable {
    case signed
    case unsigned
    case invalid
    case unknown
}
