import Foundation

enum ProfileType: String, Sendable, Codable, CaseIterable {
    case development
    case adHoc
    case appStore
    case enterprise
    case unknown
}

struct ProvisioningProfile: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let name: String
    let uuid: String
    let teamIdentifiers: [String]
    let applicationIdentifierPrefix: [String]
    let creationDate: Date
    let expirationDate: Date
    let supportedPlatforms: [String]
    let provisionedDevices: [String]?
    let provisionsAllDevices: Bool
    let entitlements: [String: String]
    let developerCertificateFingerprints: [String]
    let profileType: ProfileType
    let appIDName: String?
    let applicationIdentifier: String?
    let importedAt: Date
    let filePath: String?

    var isExpired: Bool {
        expirationDate < Date()
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
    }

    var isExpiringSoon: Bool {
        !isExpired && daysRemaining <= 30
    }

    var teamIdentifier: String? {
        teamIdentifiers.first
    }

    var deviceCount: Int {
        provisionedDevices?.count ?? 0
    }
}
