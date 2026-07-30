import XCTest
@testable import SignFlow

final class WorkspaceManagerTests: XCTestCase {
    func testCreateAndRemoveWorkspace() async throws {
        let manager = WorkspaceManager()
        let workspace = try await manager.createWorkspace()

        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.path))

        try await manager.removeWorkspace(workspace)
        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.path))
    }

    func testCleanupOrphanedWorkspaces() async throws {
        let manager = WorkspaceManager()
        let workspace = try await manager.createWorkspace()
        XCTAssertTrue(FileManager.default.fileExists(atPath: workspace.path))

        // Create a new manager (simulating fresh launch, workspace not tracked)
        let freshManager = WorkspaceManager()
        await freshManager.cleanupOrphanedWorkspaces()

        XCTAssertFalse(FileManager.default.fileExists(atPath: workspace.path))
    }

    func testRemoveNonexistentWorkspaceDoesNotThrow() async throws {
        let manager = WorkspaceManager()
        let fakeURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try await manager.removeWorkspace(fakeURL)
    }
}
