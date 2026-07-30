import Foundation

protocol CertificateImporting: Sendable {
    func importP12(from url: URL, password: String) async throws -> SigningIdentity
}

protocol CertificateStoring: Sendable {
    func listIdentities() async throws -> [SigningIdentity]
    func identity(id: UUID) async throws -> SigningIdentity?
    func deleteIdentity(id: UUID) async throws
}

protocol ProvisioningProfileParsing: Sendable {
    func parse(profileData: Data) async throws -> ProvisioningProfile
    func parse(profileURL: URL) async throws -> ProvisioningProfile
}

protocol ProvisioningProfileStoring: Sendable {
    func save(_ profile: ProvisioningProfile, originalData: Data) async throws -> ProvisioningProfile
    func listProfiles() async throws -> [ProvisioningProfile]
    func profile(id: UUID) async throws -> ProvisioningProfile?
    func profileFileData(for id: UUID) async throws -> Data
    func deleteProfile(id: UUID) async throws
}

protocol ExpirationNotifying: Sendable {
    func scheduleExpirationWarnings(for identities: [SigningIdentity], profiles: [ProvisioningProfile]) async
    func cancelAllWarnings() async
}
