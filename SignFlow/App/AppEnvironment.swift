import Foundation
import Observation

@Observable
final class AppEnvironment {
    let ipaImporter: any IPAImporting
    let ipaExtractor: any IPAExtracting
    let ipaInspector: any IPAInspecting
    let workspaceManager: any TemporaryFileManaging

    init(
        ipaImporter: any IPAImporting = IPAImporter(),
        ipaExtractor: any IPAExtracting = SafeZIPExtractor(),
        ipaInspector: any IPAInspecting = IPAInspector(),
        workspaceManager: any TemporaryFileManaging = WorkspaceManager()
    ) {
        self.ipaImporter = ipaImporter
        self.ipaExtractor = ipaExtractor
        self.ipaInspector = ipaInspector
        self.workspaceManager = workspaceManager
    }

    func cleanupOrphanedWorkspaces() async {
        await workspaceManager.cleanupOrphanedWorkspaces()
    }
}
