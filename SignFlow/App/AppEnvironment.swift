import Foundation
import Observation

@Observable
final class AppEnvironment {
    let ipaImporter: any IPAImporting
    let ipaExtractor: any IPAExtracting
    let ipaInspector: any IPAInspecting
    let workspaceManager: any TemporaryFileManaging
    let certificateImporter: any CertificateImporting
    let certificateStore: any CertificateStoring
    let profileParser: any ProvisioningProfileParsing
    let profileStore: ProvisioningProfileStore
    let profileImporter: ProvisioningProfileImporter
    let expirationNotifier: LocalExpirationNotifier
    let preflightValidator: any SigningAssetValidating
    let signingOrchestrator: any SigningOrchestrating
    let appInstaller: any AppInstalling
    let libraryStore: LibraryStore
    let sourceStore: SourceStore
    let sourceFetcher: AltStoreSourceFetcher
    let downloadManager: DownloadManager

    /// Session cache of inspected packages for signing setup.
    var inspectedPackages: [AppPackage] = []
    var libraryApps: [LibraryAppRecord] = []
    var sources: [AppSource] = []

    init(
        ipaImporter: any IPAImporting = IPAImporter(),
        ipaExtractor: any IPAExtracting = SafeZIPExtractor(),
        ipaInspector: any IPAInspecting = IPAInspector(),
        workspaceManager: any TemporaryFileManaging = WorkspaceManager(),
        certificateStore: KeychainIdentityStore = KeychainIdentityStore(),
        profileStore: ProvisioningProfileStore = ProvisioningProfileStore(),
        profileParser: any ProvisioningProfileParsing = ProvisioningProfileParser(),
        expirationNotifier: LocalExpirationNotifier = LocalExpirationNotifier(),
        preflightValidator: any SigningAssetValidating = PreflightValidator(),
        signingOrchestrator: any SigningOrchestrating = SigningOrchestrator(),
        appInstaller: any AppInstalling = CompositeAppInstaller(),
        libraryStore: LibraryStore = LibraryStore(),
        sourceStore: SourceStore = SourceStore(),
        sourceFetcher: AltStoreSourceFetcher = AltStoreSourceFetcher(),
        downloadManager: DownloadManager = DownloadManager()
    ) {
        self.ipaImporter = ipaImporter
        self.ipaExtractor = ipaExtractor
        self.ipaInspector = ipaInspector
        self.workspaceManager = workspaceManager
        self.certificateStore = certificateStore
        self.certificateImporter = P12Importer(store: certificateStore, workspaceManager: workspaceManager)
        self.profileParser = profileParser
        self.profileStore = profileStore
        self.profileImporter = ProvisioningProfileImporter(parser: profileParser, store: profileStore)
        self.expirationNotifier = expirationNotifier
        self.preflightValidator = preflightValidator
        self.signingOrchestrator = signingOrchestrator
        self.appInstaller = appInstaller
        self.libraryStore = libraryStore
        self.sourceStore = sourceStore
        self.sourceFetcher = sourceFetcher
        self.downloadManager = downloadManager
    }

    func cleanupOrphanedWorkspaces() async {
        await workspaceManager.cleanupOrphanedWorkspaces()
    }

    func refreshExpirationWarnings() async {
        do {
            let identities = try await certificateStore.listIdentities()
            let profiles = try await profileStore.listProfiles()
            await expirationNotifier.scheduleExpirationWarnings(for: identities, profiles: profiles)
        } catch {
            // Non-fatal
        }
    }

    @MainActor
    func rememberInspected(_ package: AppPackage, sourceName: String? = nil) {
        inspectedPackages.removeAll { $0.id == package.id }
        inspectedPackages.insert(package, at: 0)
        Task {
            let record = await libraryStore.recordFromPackage(package, kind: .imported, sourceName: sourceName)
            try? await libraryStore.save(record)
            await refreshLibrary()
        }
    }

    @MainActor
    func rememberSigned(_ result: SigningJobResult) {
        Task {
            let record = await libraryStore.recordFromSigningResult(result)
            try? await libraryStore.save(record)
            if SignFlowPreferences.signingOptions.deleteImportedAfterSigning {
                let imported = libraryApps.filter {
                    $0.kind == .imported && $0.bundleIdentifier == result.primaryBundleIdentifier
                }
                try? await libraryStore.delete(ids: Set(imported.map(\.id)))
            }
            await refreshLibrary()
        }
    }

    @MainActor
    func refreshLibrary() async {
        libraryApps = (try? await libraryStore.listApps()) ?? []
    }

    @MainActor
    func refreshSources() async {
        sources = (try? await sourceStore.listSources()) ?? []
    }
}
