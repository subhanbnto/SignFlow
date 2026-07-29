import Foundation

struct IPAImportResult: Sendable {
    let workspaceURL: URL
    let copiedFileURL: URL
    let sha256: String
    let fileSize: UInt64
    let originalFilename: String
}

protocol IPAImporting: Sendable {
    func importIPA(from sourceURL: URL, workspace: URL) async throws -> IPAImportResult
}
