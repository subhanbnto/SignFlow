import Foundation

protocol IPAExtracting: Sendable {
    func extract(
        archiveURL: URL,
        to destinationURL: URL,
        limits: ArchiveLimits
    ) async throws -> URL
}
