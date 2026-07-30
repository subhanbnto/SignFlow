import Foundation
import OSLog

final class IPAImporter: IPAImporting, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "IPAImporter")

    func importIPA(from sourceURL: URL, workspace: URL) async throws -> IPAImportResult {
        try Task.checkCancellation()

        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let originalFilename = sourceURL.lastPathComponent
        let destinationURL = workspace.appendingPathComponent(originalFilename)

        Self.logger.info("Importing IPA: \(originalFilename, privacy: .public)")

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        try Task.checkCancellation()

        let attrs = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
        let fileSize = attrs[.size] as? UInt64 ?? 0

        let sha256 = try await SHA256Hasher.hash(fileAt: destinationURL)

        return IPAImportResult(
            workspaceURL: workspace,
            copiedFileURL: destinationURL,
            sha256: sha256,
            fileSize: fileSize,
            originalFilename: originalFilename
        )
    }
}
