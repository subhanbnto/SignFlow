import Foundation
import Security
import OSLog

/// Stores SecIdentity items in the Keychain and keeps metadata in a local JSON index.
actor KeychainIdentityStore: CertificateStoring {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "Keychain")
    private static let metadataFileName = "signing-identities.json"

    private let requireUserPresence: Bool
    private let fileManager: FileManager

    init(requireUserPresence: Bool = false, fileManager: FileManager = .default) {
        self.requireUserPresence = requireUserPresence
        self.fileManager = fileManager
    }

    // MARK: - CertificateStoring

    func listIdentities() async throws -> [SigningIdentity] {
        try loadMetadata().sorted { $0.importedAt > $1.importedAt }
    }

    func identity(id: UUID) async throws -> SigningIdentity? {
        try loadMetadata().first { $0.id == id }
    }

    func deleteIdentity(id: UUID) async throws {
        var identities = try loadMetadata()
        guard let index = identities.firstIndex(where: { $0.id == id }) else { return }
        let identity = identities[index]

        try deleteFromKeychain(persistentReference: identity.keychainReference)
        identities.remove(at: index)
        try saveMetadata(identities)
        Self.logger.info("Deleted signing identity \(identity.fingerprintSHA256.prefix(12), privacy: .public)")
    }

    // MARK: - Import support

    func storeIdentity(
        secIdentity: SecIdentity,
        metadata: CertificateMetadataExtractor.Metadata
    ) async throws -> SigningIdentity {
        // Avoid duplicates by fingerprint
        var identities = try loadMetadata()
        if let existing = identities.first(where: { $0.fingerprintSHA256 == metadata.fingerprintSHA256 }) {
            return existing
        }

        let persistentRef = try addToKeychain(secIdentity: secIdentity, label: metadata.commonName)

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
            keychainReference: persistentRef,
            hasPrivateKey: true,
            importedAt: Date()
        )

        identities.append(identity)
        try saveMetadata(identities)
        Self.logger.info("Stored signing identity \(metadata.fingerprintSHA256.prefix(12), privacy: .public)")
        return identity
    }

    // MARK: - Keychain

    private func addToKeychain(secIdentity: SecIdentity, label: String) throws -> Data {
        var attributes: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecValueRef: secIdentity,
            kSecAttrLabel: label,
            kSecReturnPersistentRef: true,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        if requireUserPresence {
            var error: Unmanaged<CFError>?
            if let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .userPresence,
                &error
            ) {
                attributes[kSecAttrAccessControl] = access
                attributes.removeValue(forKey: kSecAttrAccessible)
            }
        }

        var result: CFTypeRef?
        let status = SecItemAdd(attributes as CFDictionary, &result)

        if status == errSecDuplicateItem {
            // Reuse the existing identity rather than deleting Keychain material.
            let existingQuery: [CFString: Any] = [
                kSecClass: kSecClassIdentity,
                kSecAttrLabel: label,
                kSecReturnPersistentRef: true,
                kSecMatchLimit: kSecMatchLimitOne
            ]
            var existingResult: CFTypeRef?
            let lookupStatus = SecItemCopyMatching(existingQuery as CFDictionary, &existingResult)
            guard lookupStatus == errSecSuccess, let ref = existingResult as? Data else {
                throw keychainError(operation: "look up existing identity", status: lookupStatus)
            }
            return ref
        }

        guard status == errSecSuccess, let ref = result as? Data else {
            throw keychainError(operation: "store identity", status: status)
        }
        return ref
    }

    private func deleteFromKeychain(persistentReference: Data) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecValuePersistentRef: persistentReference
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
            throw SignFlowError.cleanupFailed(detail: "\(message) (\(status)).")
        }
    }

    private func keychainError(operation: String, status: OSStatus) -> SignFlowError {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Keychain error"
        Self.logger.error("Failed to \(operation, privacy: .public): \(message, privacy: .public) (\(status))")
        return .internalError(detail: "Could not \(operation): \(message) (\(status)).")
    }

    // MARK: - Metadata persistence

    private var metadataURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SignFlow", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = dir
        try? mutable.setResourceValues(values)
        return dir.appendingPathComponent(Self.metadataFileName)
    }

    private func loadMetadata() throws -> [SigningIdentity] {
        let url = metadataURL
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([SigningIdentity].self, from: data)
    }

    private func saveMetadata(_ identities: [SigningIdentity]) throws {
        let data = try JSONEncoder().encode(identities)
        try data.write(to: metadataURL, options: .atomic)
    }
}
