import Foundation

enum SignFlowError: LocalizedError, Sendable {
    // IPA import
    case invalidIPA(detail: String)
    case unsupportedArchive(detail: String)
    case archiveInputTooLarge(sizeBytes: UInt64, limitBytes: UInt64)

    // Extraction
    case archiveExtractionLimitExceeded(limit: String, actual: String)
    case unsafeArchivePath(path: String)
    case unsafeSymbolicLink(path: String)

    // Payload
    case missingPayloadDirectory
    case multiplePayloadDirectories
    case missingPrimaryApplication
    case multiplePrimaryApplications(count: Int)

    // Info.plist / executable
    case malformedInfoPlist(detail: String)
    case missingExecutable(name: String)
    case unsupportedMachO(detail: String)
    case unsupportedArchitecture(arch: String)

    // Certificate (M2+)
    case invalidP12(detail: String)
    case incorrectP12Password
    case missingSigningIdentity
    case missingPrivateKey
    case expiredCertificate(name: String, expiredAt: Date)
    case invalidCertificate(detail: String)

    // Profile (M2+)
    case malformedProvisioningProfile(detail: String)
    case expiredProvisioningProfile(name: String, expiredAt: Date)
    case certificateNotIncludedInProfile
    case teamIdentifierMismatch(expected: String, actual: String)
    case appIdentifierMismatch(expected: String, actual: String)
    case deviceNotProvisioned

    // Entitlements (M3+)
    case unsupportedEntitlement(key: String)
    case nestedBundleRequiresSeparateProfile(bundleID: String)

    // Signing (M4+)
    case signingFailed(detail: String)
    case signatureVerificationFailed(component: String, detail: String)
    case outputPackagingFailed(detail: String)

    // Installation (M6+)
    case installationUnavailable(reason: String)
    case installationFailed(detail: String)

    // General
    case userCancelled
    case cleanupFailed(detail: String)
    case internalError(detail: String)

    var errorDescription: String? { title }

    var title: String {
        switch self {
        case .invalidIPA: return "Invalid IPA File"
        case .unsupportedArchive: return "Unsupported Archive"
        case .archiveInputTooLarge: return "File Too Large"
        case .archiveExtractionLimitExceeded: return "Extraction Limit Exceeded"
        case .unsafeArchivePath: return "Unsafe Archive Path"
        case .unsafeSymbolicLink: return "Unsafe Symbolic Link"
        case .missingPayloadDirectory: return "Missing Payload"
        case .multiplePayloadDirectories: return "Multiple Payload Directories"
        case .missingPrimaryApplication: return "No Application Found"
        case .multiplePrimaryApplications: return "Multiple Applications"
        case .malformedInfoPlist: return "Invalid Info.plist"
        case .missingExecutable: return "Missing Executable"
        case .unsupportedMachO: return "Unsupported Binary"
        case .unsupportedArchitecture: return "Unsupported Architecture"
        case .invalidP12: return "Invalid Certificate File"
        case .incorrectP12Password: return "Wrong Password"
        case .missingSigningIdentity: return "No Signing Identity"
        case .missingPrivateKey: return "No Private Key"
        case .expiredCertificate: return "Expired Certificate"
        case .invalidCertificate: return "Invalid Certificate"
        case .malformedProvisioningProfile: return "Invalid Profile"
        case .expiredProvisioningProfile: return "Expired Profile"
        case .certificateNotIncludedInProfile: return "Certificate Not in Profile"
        case .teamIdentifierMismatch: return "Team Mismatch"
        case .appIdentifierMismatch: return "App ID Mismatch"
        case .deviceNotProvisioned: return "Device Not Provisioned"
        case .unsupportedEntitlement: return "Unsupported Entitlement"
        case .nestedBundleRequiresSeparateProfile: return "Profile Required"
        case .signingFailed: return "Signing Failed"
        case .signatureVerificationFailed: return "Verification Failed"
        case .outputPackagingFailed: return "Packaging Failed"
        case .installationUnavailable: return "Installation Unavailable"
        case .installationFailed: return "Installation Failed"
        case .userCancelled: return "Cancelled"
        case .cleanupFailed: return "Cleanup Failed"
        case .internalError: return "Internal Error"
        }
    }

    var explanation: String {
        switch self {
        case .invalidIPA(let detail):
            return "The selected file is not a valid IPA archive. \(detail)"
        case .unsupportedArchive(let detail):
            return "The archive format is not supported. \(detail)"
        case .archiveInputTooLarge(let size, let limit):
            return "The file is \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)) which exceeds the \(ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)) limit."
        case .archiveExtractionLimitExceeded(let limit, let actual):
            return "Extraction stopped because the \(limit) limit was reached (actual: \(actual))."
        case .unsafeArchivePath(let path):
            return "The archive contains a path that would escape the workspace: \(path). This may indicate a malicious file."
        case .unsafeSymbolicLink(let path):
            return "The archive contains a symbolic link that points outside the workspace: \(path). This may indicate a malicious file."
        case .missingPayloadDirectory:
            return "The IPA does not contain a Payload directory. A valid IPA must contain Payload/<AppName>.app."
        case .multiplePayloadDirectories:
            return "The IPA contains multiple Payload directories, which is not supported."
        case .missingPrimaryApplication:
            return "No .app bundle was found inside the Payload directory."
        case .multiplePrimaryApplications(let count):
            return "Found \(count) .app bundles inside Payload. Only single-app IPAs are supported in this version."
        case .malformedInfoPlist(let detail):
            return "The application's Info.plist could not be read or is missing required keys. \(detail)"
        case .missingExecutable(let name):
            return "The main executable '\(name)' was not found inside the application bundle."
        case .unsupportedMachO(let detail):
            return "The binary format is not recognized. \(detail)"
        case .unsupportedArchitecture(let arch):
            return "The architecture '\(arch)' is not supported on this device."
        case .userCancelled:
            return "The operation was cancelled."
        case .cleanupFailed(let detail):
            return "Temporary files could not be fully removed. \(detail)"
        case .internalError(let detail):
            return "An unexpected error occurred. \(detail)"
        default:
            return "This feature is not yet implemented."
        }
    }

    var suggestedResolution: String {
        switch self {
        case .invalidIPA:
            return "Select a valid .ipa file exported from Xcode or another trusted source."
        case .archiveInputTooLarge:
            return "Try a smaller IPA file, or adjust the size limit in settings."
        case .archiveExtractionLimitExceeded:
            return "The archive may be corrupted or contain an unusually large number of files."
        case .unsafeArchivePath, .unsafeSymbolicLink:
            return "Do not import this file. It may have been crafted to exploit your device."
        case .missingPayloadDirectory, .missingPrimaryApplication:
            return "Ensure the IPA was exported correctly from Xcode."
        case .malformedInfoPlist:
            return "The application may be corrupted. Try re-exporting from Xcode."
        case .missingExecutable:
            return "The application bundle appears incomplete."
        case .userCancelled:
            return "You can try again when ready."
        default:
            return "Check the technical details for more information."
        }
    }
}
