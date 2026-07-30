import Foundation

/// Fallback installer used when no hosted backend is configured.
struct ExportOnlyInstaller: AppInstalling {
    var isAvailable: Bool {
        get async { false }
    }

    var unavailableReason: String? {
        get async {
            "Configure the Cloudflare installer backend in Settings for Ad Hoc/Enterprise OTA installs, or export the IPA for Xcode, Apple Configurator, AltStore, or SideStore."
        }
    }

    func eligibility(for request: InstallationRequest) async -> InstallationEligibility {
        InstallationEligibilityEvaluator.evaluate(profileType: request.profileType, accountPlan: nil)
    }

    func testConnection() async throws -> String {
        throw SignFlowError.installationNotConfigured
    }

    func install(
        request: InstallationRequest,
        progressHandler: @escaping @Sendable (InstallationProgress) -> Void
    ) async throws -> InstallationResult {
        let eligibility = await eligibility(for: request)
        switch eligibility {
        case .externalHandoff(let reason):
            progressHandler(InstallationProgress(stage: .complete, fractionCompleted: 1, message: reason))
            return InstallationResult(
                kind: .externalShare,
                message: reason,
                installURL: nil,
                manifestURL: nil,
                expiresAt: nil
            )
        case .hostedOTA:
            throw SignFlowError.installationNotConfigured
        case .unavailable(let reason):
            throw SignFlowError.installationUnavailable(reason: reason)
        }
    }
}
