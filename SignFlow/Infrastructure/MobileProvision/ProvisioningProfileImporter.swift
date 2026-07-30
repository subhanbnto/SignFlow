import Foundation
import OSLog

/// Orchestrates profile file import: parse → store.
final class ProvisioningProfileImporter: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "ProfileImporter")

    private let parser: any ProvisioningProfileParsing
    private let store: ProvisioningProfileStore

    init(
        parser: any ProvisioningProfileParsing = ProvisioningProfileParser(),
        store: ProvisioningProfileStore = ProvisioningProfileStore()
    ) {
        self.parser = parser
        self.store = store
    }

    func importProfile(from url: URL) async throws -> ProvisioningProfile {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let parsed = try await parser.parse(profileData: data)

        if parsed.isExpired {
            Self.logger.warning("Importing expired profile \(parsed.uuid, privacy: .public)")
        }

        return try await store.save(parsed, originalData: data)
    }
}
