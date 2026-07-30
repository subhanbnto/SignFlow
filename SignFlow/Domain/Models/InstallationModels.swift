import Foundation

enum InstallationMethod: String, Sendable, Codable, CaseIterable {
    case hostedOTA
    case externalHandoff
    case unavailable

    var title: String {
        switch self {
        case .hostedOTA: return "Install on This Device"
        case .externalHandoff: return "Open in Installer"
        case .unavailable: return "Installation Unavailable"
        }
    }
}

enum InstallationEligibility: Sendable, Hashable {
    case hostedOTA(reason: String)
    case externalHandoff(reason: String)
    case unavailable(reason: String)

    var method: InstallationMethod {
        switch self {
        case .hostedOTA: return .hostedOTA
        case .externalHandoff: return .externalHandoff
        case .unavailable: return .unavailable
        }
    }

    var reason: String {
        switch self {
        case .hostedOTA(let reason), .externalHandoff(let reason), .unavailable(let reason):
            return reason
        }
    }
}

struct InstallationRequest: Sendable, Hashable {
    let ipaURL: URL
    let outputSHA256: String
    let bundleIdentifier: String
    let bundleVersion: String
    let displayName: String
    let profileType: ProfileType
    let profileName: String
    let outputFilename: String
    let byteSize: UInt64
}

struct InstallationProgress: Sendable, Hashable {
    enum Stage: String, Sendable {
        case preparing = "Preparing"
        case uploading = "Uploading"
        case finalizing = "Finalizing"
        case handingOff = "Handing off to iOS"
        case complete = "Complete"
        case failed = "Failed"
    }

    var stage: Stage
    var fractionCompleted: Double
    var message: String
}

struct InstallationResult: Sendable, Hashable {
    enum Kind: String, Sendable {
        case otaHandoff
        case externalShare
    }

    let kind: Kind
    let message: String
    let installURL: URL?
    let manifestURL: URL?
    let expiresAt: Date?
}

enum InstallationEligibilityEvaluator {
    static func evaluate(profileType: ProfileType, accountPlan: DeveloperAccountPlan?) -> InstallationEligibility {
        switch profileType {
        case .adHoc:
            return .hostedOTA(
                reason: "Ad Hoc profiles can install over HTTPS OTA on devices listed in the profile."
            )
        case .enterprise:
            return .hostedOTA(
                reason: "Enterprise profiles can install over HTTPS OTA after the organization certificate is trusted."
            )
        case .development:
            return .hostedOTA(
                reason: "Development profiles can install over HTTPS OTA when this device is registered in the provisioning profile."
            )
        case .appStore:
            return .unavailable(
                reason: "App Store profiles are for App Store distribution, not direct device installation from SignFlow."
            )
        case .unknown:
            if accountPlan == .free {
                return .externalHandoff(
                    reason: "Free-account builds require an external installer such as AltStore, SideStore, Xcode, or Apple Configurator."
                )
            }
            return .unavailable(
                reason: "This profile type cannot be used for direct installation. Export the IPA and install with an authorized workflow."
            )
        }
    }
}
