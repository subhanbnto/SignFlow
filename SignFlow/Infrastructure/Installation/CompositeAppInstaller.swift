import Foundation

/// Chooses the hosted OTA installer when configured, otherwise the export-only fallback.
actor CompositeAppInstaller: AppInstalling {
    private let hosted: HostedOTAInstaller
    private let fallback: ExportOnlyInstaller

    init(
        hosted: HostedOTAInstaller = HostedOTAInstaller(),
        fallback: ExportOnlyInstaller = ExportOnlyInstaller()
    ) {
        self.hosted = hosted
        self.fallback = fallback
    }

    var isAvailable: Bool {
        get async { await hosted.isAvailable }
    }

    var unavailableReason: String? {
        get async {
            if await hosted.isAvailable { return nil }
            if let reason = await hosted.unavailableReason {
                return reason
            }
            return await fallback.unavailableReason
        }
    }

    func eligibility(for request: InstallationRequest) async -> InstallationEligibility {
        await hosted.eligibility(for: request)
    }

    func testConnection() async throws -> String {
        try await hosted.testConnection()
    }

    func install(
        request: InstallationRequest,
        progressHandler: @escaping @Sendable (InstallationProgress) -> Void
    ) async throws -> InstallationResult {
        if await hosted.isAvailable {
            return try await hosted.install(request: request, progressHandler: progressHandler)
        }
        return try await fallback.install(request: request, progressHandler: progressHandler)
    }
}
