import Foundation

enum CertificateType: String, Sendable, Codable, CaseIterable {
    case development
    case distribution
    case enterprise
    case unknown
}

struct SigningIdentity: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let displayName: String
    let commonName: String
    let issuer: String
    let teamIdentifier: String?
    let serialNumber: String
    let certificateType: CertificateType
    let validFrom: Date
    let expiresAt: Date
    let fingerprintSHA256: String
    let keychainReference: Data
    let hasPrivateKey: Bool
    let importedAt: Date

    var isExpired: Bool {
        expiresAt < Date()
    }

    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: expiresAt).day ?? 0
    }

    var isExpiringSoon: Bool {
        !isExpired && daysRemaining <= 30
    }
}
