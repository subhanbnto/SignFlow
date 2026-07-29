import Foundation

// MARK: - M2+ Protocols (Certificate & Profile Management)

protocol CertificateImporting: Sendable {
    func importP12(from url: URL, password: String) async throws
}

protocol CertificateStoring: Sendable {
    func listIdentities() async throws -> [SigningIdentity]
    func deleteIdentity(id: UUID) async throws
}

protocol ProvisioningProfileParsing: Sendable {
    func parse(profileURL: URL) async throws -> ProvisioningProfile
}

// MARK: - M3+ Protocols (Preflight Validation)

protocol SigningAssetValidating: Sendable {
    func validate(
        package: AppPackage,
        identity: SigningIdentity,
        profiles: [ProvisioningProfile]
    ) async -> PreflightReport
}

protocol EntitlementResolving: Sendable {
    func resolve(
        requested: [String: Any],
        permitted: [String: Any],
        strategy: EntitlementStrategy
    ) -> EntitlementResolutionResult
}

protocol BundleIdentifierRewriting: Sendable {
    func computeMappings(
        original: String,
        replacement: String,
        nestedBundles: [NestedBundle]
    ) -> [BundleIDMapping]
}

// MARK: - M4+ Protocols (Signing)

protocol NestedCodeDiscovering: Sendable {
    func discoverNestedCode(in appURL: URL) async throws -> [NestedBundle]
}

protocol SigningOrderPlanning: Sendable {
    func planSigningOrder(bundles: [NestedBundle]) -> [SigningUnit]
}

protocol CodeSigning: Sendable {
    func sign(target: URL, identity: Any, entitlements: Data?) async throws
}

protocol SignatureVerifying: Sendable {
    func verify(target: URL) async throws -> VerificationResult
}

protocol IPARepackaging: Sendable {
    func repackage(appURL: URL, outputURL: URL) async throws -> URL
}

// MARK: - M6+ Protocols (Installation)

protocol AppInstalling: Sendable {
    var isAvailable: Bool { get async }
    var unavailableReason: String? { get async }
    func install(ipaURL: URL) async throws
}

// MARK: - M7+ Protocols (Sources)

protocol SourceFetching: Sendable {
    func fetchSources() async throws -> [AppSource]
}

protocol SigningHistoryStoring: Sendable {
    func recordResult(_ result: SigningResult) async throws
    func listHistory() async throws -> [SigningResult]
}

protocol DiagnosticsExporting: Sendable {
    func exportDiagnostics() async throws -> URL
}

// MARK: - Placeholder types for future milestones

struct SigningIdentity: Identifiable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let commonName: String
}

struct ProvisioningProfile: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let uuid: String
}

struct PreflightReport: Sendable {
    let canSign: Bool
}

enum EntitlementStrategy: String, Sendable {
    case strict
    case permittedSubset
    case advancedReview
}

struct EntitlementResolutionResult: Sendable {
    let resolvedEntitlements: [String: String]
}

struct BundleIDMapping: Sendable {
    let original: String
    let replacement: String
}

struct SigningUnit: Sendable {
    let path: String
    let order: Int
}

struct VerificationResult: Sendable {
    let passed: Bool
}

struct AppSource: Identifiable, Sendable {
    let id: UUID
    let name: String
    let url: URL
}

struct SigningResult: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let success: Bool
}
