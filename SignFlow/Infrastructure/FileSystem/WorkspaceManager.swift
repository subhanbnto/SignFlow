import Foundation
import OSLog

actor WorkspaceManager: TemporaryFileManaging {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "WorkspaceManager")
    private static let workspaceDirectoryName = "SignFlowWorkspaces"

    private var activeWorkspaces: Set<URL> = []

    private var baseDirectory: URL {
        get throws {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            return caches.appendingPathComponent(Self.workspaceDirectoryName, isDirectory: true)
        }
    }

    func createWorkspace() async throws -> URL {
        let base = try baseDirectory
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let id = UUID().uuidString
        let workspaceURL = base.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: false)

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableURL = workspaceURL
        try mutableURL.setResourceValues(resourceValues)

        activeWorkspaces.insert(workspaceURL)
        Self.logger.info("Created workspace: \(id, privacy: .public)")
        return workspaceURL
    }

    func removeWorkspace(_ url: URL) async throws {
        activeWorkspaces.remove(url)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
        Self.logger.info("Removed workspace")
    }

    func cleanupOrphanedWorkspaces() async {
        do {
            let base = try baseDirectory
            guard FileManager.default.fileExists(atPath: base.path) else { return }

            let contents = try FileManager.default.contentsOfDirectory(
                at: base,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            for item in contents where !activeWorkspaces.contains(item) {
                try? FileManager.default.removeItem(at: item)
                Self.logger.info("Cleaned orphaned workspace")
            }
        } catch {
            Self.logger.error("Failed to clean orphaned workspaces: \(error.localizedDescription, privacy: .public)")
        }
    }
}
