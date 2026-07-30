import Foundation

struct BundleIDMapping: Identifiable, Hashable, Sendable {
    let id: UUID
    let original: String
    let replacement: String
    let componentPath: String?
    let isPrimary: Bool

    init(original: String, replacement: String, componentPath: String? = nil, isPrimary: Bool = false) {
        self.id = UUID()
        self.original = original
        self.replacement = replacement
        self.componentPath = componentPath
        self.isPrimary = isPrimary
    }
}

struct EntitlementReport: Identifiable, Hashable, Sendable {
    let id: UUID
    let bundleIdentifier: String
    let componentPath: String?
    let requestedKeys: [String]
    let permittedKeys: [String]
    let keptKeys: [String]
    let removedKeys: [String]
    let issues: [ValidationIssue]

    init(
        bundleIdentifier: String,
        componentPath: String? = nil,
        requestedKeys: [String],
        permittedKeys: [String],
        keptKeys: [String],
        removedKeys: [String],
        issues: [ValidationIssue]
    ) {
        self.id = UUID()
        self.bundleIdentifier = bundleIdentifier
        self.componentPath = componentPath
        self.requestedKeys = requestedKeys
        self.permittedKeys = permittedKeys
        self.keptKeys = keptKeys
        self.removedKeys = removedKeys
        self.issues = issues
    }
}

struct EntitlementResolutionResult: Sendable {
    let resolvedEntitlements: [String: Any]
    let removedKeys: [String]
    let issues: [ValidationIssue]
}

enum EntitlementStrategy: String, Sendable, CaseIterable, Codable {
    case strict
    case permittedSubset
    case advancedReview

    var displayName: String {
        switch self {
        case .strict: return "Strict"
        case .permittedSubset: return "Permitted Subset"
        case .advancedReview: return "Advanced Review"
        }
    }

    var explanation: String {
        switch self {
        case .strict:
            return "Fail if any requested entitlement is not permitted by the profile."
        case .permittedSubset:
            return "Keep only entitlements permitted by the profile and show what will be removed."
        case .advancedReview:
            return "Show every requested and available entitlement; require confirmation before signing."
        }
    }
}

struct PreflightReport: Sendable {
    let packageSummary: String
    let identitySummary: String
    let profileSummary: String
    let bundleIdentifierMappings: [BundleIDMapping]
    let entitlementReports: [EntitlementReport]
    let issues: [ValidationIssue]
    let canSign: Bool

    var fatalIssues: [ValidationIssue] {
        issues.filter { $0.severity == .fatal }
    }

    var warnings: [ValidationIssue] {
        issues.filter { $0.severity == .warning }
    }
}

struct SigningConfiguration: Hashable, Sendable {
    var package: AppPackage
    var identity: SigningIdentity
    var profile: ProvisioningProfile
    var requestedDisplayName: String?
    var requestedPrimaryBundleIdentifier: String?
    var entitlementStrategy: EntitlementStrategy
    var removeUnsupportedEntitlements: Bool
    var outputFilename: String
    var options: SigningOptions = SignFlowPreferences.signingOptions

    var effectiveBundleIdentifier: String {
        let trimmed = requestedPrimaryBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = trimmed.isEmpty ? package.primaryBundleIdentifier : trimmed
        return options.resolvedIdentifier(for: base) ?? base
    }

    var effectiveDisplayName: String {
        let trimmed = requestedDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = trimmed.isEmpty ? package.displayName : trimmed
        return options.resolvedDisplayName(for: package.displayName) ?? base
    }
}

struct SigningProgress: Sendable {
    enum Stage: String, Sendable, CaseIterable {
        case preparing = "Preparing workspace"
        case extracting = "Extracting application"
        case inspecting = "Inspecting nested code"
        case resolvingIdentifiers = "Resolving identifiers"
        case resolvingEntitlements = "Resolving entitlements"
        case embeddingProfiles = "Embedding provisioning profiles"
        case signingLibraries = "Signing libraries"
        case signingFrameworks = "Signing frameworks"
        case signingExtensions = "Signing extensions"
        case signingNestedApps = "Signing nested applications"
        case signingMainApp = "Signing main application"
        case verifying = "Verifying signatures"
        case packaging = "Packaging output"
        case hashing = "Calculating output hash"
        case cleaning = "Cleaning temporary files"
        case complete = "Complete"
        case failed = "Failed"
    }

    var currentStage: Stage
    var completedUnits: Int
    var totalUnits: Int
    var currentComponent: String?
    var recentMessage: String
    var startedAt: Date

    var fractionCompleted: Double {
        guard totalUnits > 0 else { return 0 }
        return min(1.0, Double(completedUnits) / Double(totalUnits))
    }
}

struct NestedVerificationItem: Hashable, Sendable {
    let path: String
    let verified: Bool
}

struct VerificationReport: Hashable, Sendable {
    let mainAppVerified: Bool
    let nestedComponents: [NestedVerificationItem]
    let profileEmbedded: Bool
    let packageStructureVerified: Bool
    let issues: [ValidationIssue]
    let overallStatus: Bool
}

struct SigningJobResult: Identifiable, Hashable, Sendable {
    let id: UUID
    let outputURL: URL
    let outputSHA256: String
    let signedAt: Date
    let finalBundleIdentifiers: [String]
    let identitySummary: String
    let profileSummary: String
    let verificationReport: VerificationReport
    let warnings: [ValidationIssue]
    let outputFilename: String
    let displayName: String
    let bundleVersion: String
    let primaryBundleIdentifier: String
    let profileType: ProfileType
    let byteSize: UInt64

    func installationRequest() -> InstallationRequest {
        InstallationRequest(
            ipaURL: outputURL,
            outputSHA256: outputSHA256,
            bundleIdentifier: primaryBundleIdentifier,
            bundleVersion: bundleVersion,
            displayName: displayName,
            profileType: profileType,
            profileName: profileSummary,
            outputFilename: outputFilename,
            byteSize: byteSize
        )
    }
}
