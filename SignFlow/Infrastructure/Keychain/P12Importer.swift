import Foundation
import Security
import OSLog

final class P12Importer: CertificateImporting, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "P12Importer")

    private let store: KeychainIdentityStore
    private let workspaceManager: any TemporaryFileManaging

    init(
        store: KeychainIdentityStore = KeychainIdentityStore(),
        workspaceManager: any TemporaryFileManaging = WorkspaceManager()
    ) {
        self.store = store
        self.workspaceManager = workspaceManager
    }

    func importP12(from url: URL, password: String) async throws -> SigningIdentity {
        try Task.checkCancellation()

        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        let workspace = try await workspaceManager.createWorkspace()
        defer {
            Task { try? await workspaceManager.removeWorkspace(workspace) }
        }

        let tempP12 = workspace.appendingPathComponent("import.p12")
        try FileManager.default.copyItem(at: url, to: tempP12)

        let p12Data = try Data(contentsOf: tempP12)
        try? FileManager.default.removeItem(at: tempP12)

        let parsed = try PKCS12Parser.parse(data: p12Data, password: password)
        _ = password // never persist

        if parsed.metadata.expiresAt < Date() {
            Self.logger.warning("Importing expired certificate \(parsed.metadata.fingerprintSHA256.prefix(12), privacy: .public)")
        }

        let stored = try await store.storeIdentity(secIdentity: parsed.identity, metadata: parsed.metadata)
        Self.logger.info("Imported P12 identity \(parsed.metadata.fingerprintSHA256.prefix(12), privacy: .public)")
        return stored
    }
}
