import Foundation
import OSLog

actor ProvisioningProfileStore: ProvisioningProfileStoring {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "ProfileStore")
    private static let metadataFileName = "provisioning-profiles.json"
    private static let profilesDirectoryName = "Profiles"
    private static let appSupportFolderName = "SignFlow"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func save(_ profile: ProvisioningProfile, originalData: Data) async throws -> ProvisioningProfile {
        var profiles = try loadMetadata()

        // Replace existing by UUID and remove any stale file for that UUID.
        if let existing = profiles.first(where: { $0.uuid == profile.uuid }) {
            try? removeProfileFile(for: existing)
        }
        profiles.removeAll { $0.uuid == profile.uuid }

        let fileURL = try canonicalFileURL(forUUID: profile.uuid)
        try originalData.write(to: fileURL, options: .atomic)

        let stored = copy(profile, filePath: fileURL.path, importedAt: Date())
        profiles.append(stored)
        try saveMetadata(profiles.map { strippedForPersistence($0) })
        Self.logger.info("Saved profile \(stored.uuid, privacy: .public)")
        return stored
    }

    func listProfiles() async throws -> [ProvisioningProfile] {
        let hydrated = try hydrateAll(loadMetadata())
        // Persist healed paths so future launches don't keep stale absolute locations.
        try? saveMetadata(hydrated.map { strippedForPersistence($0) })
        return hydrated.sorted { $0.importedAt > $1.importedAt }
    }

    func profile(id: UUID) async throws -> ProvisioningProfile? {
        try await listProfiles().first { $0.id == id }
    }

    func profileFileData(for id: UUID) async throws -> Data {
        guard let profile = try await profile(id: id) else {
            throw SignFlowError.signingFailed(detail: "Provisioning profile is no longer available. Re-import it.")
        }
        guard let path = profile.filePath, fileManager.fileExists(atPath: path) else {
            throw SignFlowError.signingFailed(
                detail: "Provisioning profile file is missing from storage. Re-import the .mobileprovision file."
            )
        }
        return try Data(contentsOf: URL(fileURLWithPath: path))
    }

    func deleteProfile(id: UUID) async throws {
        var profiles = try loadMetadata()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let profile = profiles[index]
        try? removeProfileFile(for: profile)
        profiles.remove(at: index)
        try saveMetadata(profiles.map { strippedForPersistence($0) })
        Self.logger.info("Deleted profile \(profile.uuid, privacy: .public)")
    }

    // MARK: - Path resolution

    /// Resolves the on-disk profile location for the current app container.
    /// Absolute paths saved in metadata go stale when the container UUID changes.
    static func canonicalFileURL(
        forUUID uuid: String,
        fileManager: FileManager = .default
    ) throws -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport
            .appendingPathComponent(appSupportFolderName, isDirectory: true)
            .appendingPathComponent(profilesDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(uuid).mobileprovision")
    }

    private func canonicalFileURL(forUUID uuid: String) throws -> URL {
        try Self.canonicalFileURL(forUUID: uuid, fileManager: fileManager)
    }

    private func hydrateAll(_ profiles: [ProvisioningProfile]) throws -> [ProvisioningProfile] {
        try profiles.compactMap { profile in
            if let resolved = try resolveExistingFile(for: profile) {
                return copy(profile, filePath: resolved.path, importedAt: profile.importedAt)
            }
            Self.logger.error(
                "Dropping profile \(profile.uuid, privacy: .public) because its .mobileprovision file is missing"
            )
            return nil
        }
    }

    private func resolveExistingFile(for profile: ProvisioningProfile) throws -> URL? {
        let canonical = try canonicalFileURL(forUUID: profile.uuid)
        if fileManager.fileExists(atPath: canonical.path) {
            return canonical
        }

        // Migrate from a stale absolute path left by a previous container UUID.
        if let oldPath = profile.filePath,
           oldPath != canonical.path,
           fileManager.fileExists(atPath: oldPath) {
            do {
                if fileManager.fileExists(atPath: canonical.path) {
                    try fileManager.removeItem(at: canonical)
                }
                try fileManager.copyItem(atPath: oldPath, toPath: canonical.path)
                try? fileManager.removeItem(atPath: oldPath)
                Self.logger.info("Migrated profile file for \(profile.uuid, privacy: .public)")
                return canonical
            } catch {
                Self.logger.error("Failed to migrate profile file: \(error.localizedDescription, privacy: .public)")
                return URL(fileURLWithPath: oldPath)
            }
        }

        return nil
    }

    private func removeProfileFile(for profile: ProvisioningProfile) throws {
        let canonical = try canonicalFileURL(forUUID: profile.uuid)
        if fileManager.fileExists(atPath: canonical.path) {
            try fileManager.removeItem(at: canonical)
        }
        if let path = profile.filePath,
           path != canonical.path,
           fileManager.fileExists(atPath: path) {
            try? fileManager.removeItem(atPath: path)
        }
    }

    /// Persist relative identity (UUID) rather than trusting a frozen absolute path forever.
    private func strippedForPersistence(_ profile: ProvisioningProfile) -> ProvisioningProfile {
        copy(profile, filePath: profile.uuid + ".mobileprovision", importedAt: profile.importedAt)
    }

    private func copy(
        _ profile: ProvisioningProfile,
        filePath: String?,
        importedAt: Date
    ) -> ProvisioningProfile {
        ProvisioningProfile(
            id: profile.id,
            name: profile.name,
            uuid: profile.uuid,
            teamIdentifiers: profile.teamIdentifiers,
            applicationIdentifierPrefix: profile.applicationIdentifierPrefix,
            creationDate: profile.creationDate,
            expirationDate: profile.expirationDate,
            supportedPlatforms: profile.supportedPlatforms,
            provisionedDevices: profile.provisionedDevices,
            provisionsAllDevices: profile.provisionsAllDevices,
            entitlements: profile.entitlements,
            developerCertificateFingerprints: profile.developerCertificateFingerprints,
            profileType: profile.profileType,
            appIDName: profile.appIDName,
            applicationIdentifier: profile.applicationIdentifier,
            importedAt: importedAt,
            filePath: filePath
        )
    }

    // MARK: - Persistence

    private func baseDirectory() throws -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(Self.appSupportFolderName, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = dir
        try? mutable.setResourceValues(values)
        return dir
    }

    private var metadataURL: URL {
        get throws {
            try baseDirectory().appendingPathComponent(Self.metadataFileName)
        }
    }

    private func loadMetadata() throws -> [ProvisioningProfile] {
        let url = try metadataURL
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ProvisioningProfile].self, from: data)
    }

    private func saveMetadata(_ profiles: [ProvisioningProfile]) throws {
        let data = try JSONEncoder().encode(profiles)
        try data.write(to: try metadataURL, options: .atomic)
    }
}
