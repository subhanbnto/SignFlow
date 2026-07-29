import Foundation

protocol TemporaryFileManaging: Sendable {
    func createWorkspace() async throws -> URL
    func removeWorkspace(_ url: URL) async throws
    func cleanupOrphanedWorkspaces() async
}
