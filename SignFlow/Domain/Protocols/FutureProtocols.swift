import Foundation

// MARK: - M3 Protocols (Preflight Validation)

protocol SigningAssetValidating: Sendable {
    func validate(configuration: SigningConfiguration) async -> PreflightReport
}

protocol EntitlementResolving: Sendable {
    func resolve(
        requested: [String: Any],
        permitted: [String: Any],
        strategy: EntitlementStrategy,
        bundleIdentifier: String,
        teamIdentifier: String
    ) -> EntitlementResolutionResult
}

protocol BundleIdentifierRewriting: Sendable {
    func computeMappings(
        original: String,
        replacement: String,
        nestedBundles: [NestedBundle]
    ) -> [BundleIDMapping]

    func applyMappings(
        mappings: [BundleIDMapping],
        toAppBundle appURL: URL
    ) async throws
}

// MARK: - M4 Protocols (Signing)

protocol NestedCodeDiscovering: Sendable {
    func discoverNestedCode(in appURL: URL) async throws -> [NestedBundle]
}

protocol SigningOrderPlanning: Sendable {
    func planSigningOrder(appURL: URL, nestedBundles: [NestedBundle]) -> [SigningUnit]
}

struct SigningUnit: Identifiable, Sendable, Hashable {
    let id: UUID
    let path: URL
    let relativePath: String
    let kind: NestedBundleType
    let order: Int
    let bundleIdentifier: String?

    init(path: URL, relativePath: String, kind: NestedBundleType, order: Int, bundleIdentifier: String? = nil) {
        self.id = UUID()
        self.path = path
        self.relativePath = relativePath
        self.kind = kind
        self.order = order
        self.bundleIdentifier = bundleIdentifier
    }
}

protocol CodeSigning: Sendable {
    func signAppBundle(
        at appURL: URL,
        identity: SigningIdentity,
        profile: ProvisioningProfile,
        entitlementPlists: [String: Data],
        embedProvisioningProfile: Bool,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws
}

protocol SignatureVerifying: Sendable {
    func verify(appBundleURL: URL, expectedProfileUUID: String?) async throws -> VerificationReport
}

protocol IPARepackaging: Sendable {
    func repackage(
        payloadParentURL: URL,
        outputURL: URL,
        compressionLevel: CompressionLevelSetting
    ) async throws -> URL
}

protocol SigningOrchestrating: Sendable {
    func sign(
        configuration: SigningConfiguration,
        progressHandler: @escaping @Sendable (SigningProgress) -> Void
    ) async throws -> SigningJobResult
}

// MARK: - M6 Protocols (Installation)

protocol AppInstalling: Sendable {
    var isAvailable: Bool { get async }
    var unavailableReason: String? { get async }
    func eligibility(for request: InstallationRequest) async -> InstallationEligibility
    func testConnection() async throws -> String
    func install(
        request: InstallationRequest,
        progressHandler: @escaping @Sendable (InstallationProgress) -> Void
    ) async throws -> InstallationResult
}

// MARK: - M7+ Protocols

protocol SigningHistoryStoring: Sendable {
    func recordResult(_ result: SigningJobResult) async throws
    func listHistory() async throws -> [SigningJobResult]
}

protocol DiagnosticsExporting: Sendable {
    func exportDiagnostics() async throws -> URL
}

protocol AppModifying: Sendable {
    func apply(options: SigningOptions, toAppBundle appURL: URL, displayName: String) async throws
}

protocol TweakInjecting: Sendable {
    func inject(tweakURLs: [URL], intoAppBundle appURL: URL, intoExtensions: Bool) async throws
}
