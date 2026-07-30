import Foundation
import Security

/// In-memory certificate store for tests and preview. Does not touch the Keychain.
actor InMemoryCertificateStore: CertificateStoring {
    private var identities: [SigningIdentity] = []

    func listIdentities() async throws -> [SigningIdentity] {
        identities.sorted { $0.importedAt > $1.importedAt }
    }

    func identity(id: UUID) async throws -> SigningIdentity? {
        identities.first { $0.id == id }
    }

    func deleteIdentity(id: UUID) async throws {
        identities.removeAll { $0.id == id }
    }

    func store(
        metadata: CertificateMetadataExtractor.Metadata,
        hasPrivateKey: Bool = true
    ) -> SigningIdentity {
        if let existing = identities.first(where: { $0.fingerprintSHA256 == metadata.fingerprintSHA256 }) {
            return existing
        }
        let identity = SigningIdentity(
            id: UUID(),
            displayName: metadata.commonName,
            commonName: metadata.commonName,
            issuer: metadata.issuer,
            teamIdentifier: metadata.teamIdentifier,
            serialNumber: metadata.serialNumber,
            certificateType: metadata.certificateType,
            validFrom: metadata.validFrom,
            expiresAt: metadata.expiresAt,
            fingerprintSHA256: metadata.fingerprintSHA256,
            keychainReference: Data("in-memory".utf8),
            hasPrivateKey: hasPrivateKey,
            importedAt: Date()
        )
        identities.append(identity)
        return identity
    }
}
