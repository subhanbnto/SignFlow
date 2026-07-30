import Foundation

struct PreflightValidator: SigningAssetValidating {
    private let entitlementResolver: EntitlementResolving
    private let bundleRewriter: BundleIdentifierRewriting

    init(
        entitlementResolver: EntitlementResolving = EntitlementResolver(),
        bundleRewriter: BundleIdentifierRewriting = BundleIdentifierRewriter()
    ) {
        self.entitlementResolver = entitlementResolver
        self.bundleRewriter = bundleRewriter
    }

    func validate(configuration: SigningConfiguration) async -> PreflightReport {
        var issues: [ValidationIssue] = []
        let package = configuration.package
        let identity = configuration.identity
        let profile = configuration.profile
        let effectiveBundleID = configuration.effectiveBundleIdentifier

        // Certificate validity
        if !identity.hasPrivateKey {
            issues.append(fatal("MISSING_PRIVATE_KEY", "No Private Key",
                "The selected identity does not include a private key.",
                "Import a P12 that contains both the certificate and private key."))
        }
        if identity.isExpired {
            issues.append(fatal("EXPIRED_CERTIFICATE", "Expired Certificate",
                "The certificate '\(identity.displayName)' has expired.",
                "Create or download a new certificate from your Apple Developer account."))
        } else if identity.isExpiringSoon {
            issues.append(warning("CERT_EXPIRING", "Certificate Expiring Soon",
                "The certificate expires in \(identity.daysRemaining) days.",
                "Plan to renew the certificate before it expires."))
        }
        if identity.certificateType == .unknown {
            issues.append(warning("UNKNOWN_CERT_TYPE", "Unknown Certificate Type",
                "The certificate type could not be classified as development or distribution.",
                "Confirm this is an Apple signing certificate you are authorized to use."))
        }

        // Profile validity
        if profile.isExpired {
            issues.append(fatal("EXPIRED_PROFILE", "Expired Profile",
                "The profile '\(profile.name)' has expired.",
                "Regenerate the profile in your Apple Developer account."))
        } else if profile.isExpiringSoon {
            issues.append(warning("PROFILE_EXPIRING", "Profile Expiring Soon",
                "The profile expires in \(profile.daysRemaining) days.",
                "Regenerate the profile before it expires."))
        }

        let platforms = profile.supportedPlatforms.map { $0.lowercased() }
        if !platforms.isEmpty && !platforms.contains(where: { $0.contains("ios") || $0 == "iphoneos" }) {
            issues.append(warning("PLATFORM_CHECK", "Platform May Not Include iOS",
                "Profile platforms: \(profile.supportedPlatforms.joined(separator: ", ")).",
                "Confirm this profile is intended for iOS."))
        }

        // Certificate in profile
        if !CertificateProfileMatcher.fingerprintMatches(identity, profile: profile) {
            issues.append(fatal("CERT_NOT_IN_PROFILE", "Certificate Not in Profile",
                "The selected certificate is not listed in this provisioning profile.",
                "Select a profile that includes this certificate, or regenerate the profile."))
        }

        // Team ID
        if let identityTeam = identity.teamIdentifier,
           let profileTeam = profile.teamIdentifier,
           identityTeam != profileTeam {
            issues.append(fatal("TEAM_MISMATCH", "Team Mismatch",
                "Certificate team \(identityTeam) does not match profile team \(profileTeam).",
                "Use a certificate and profile from the same Apple Developer team."))
        }

        // App ID / bundle ID
        let teamPrefixes = profile.applicationIdentifierPrefix.isEmpty
            ? profile.teamIdentifiers
            : profile.applicationIdentifierPrefix

        let mappings = bundleRewriter.computeMappings(
            original: package.primaryBundleIdentifier,
            replacement: effectiveBundleID,
            nestedBundles: package.nestedBundles
        )

        if let appID = profile.applicationIdentifier {
            let mainOK = AppIDMatcher.matches(
                bundleIdentifier: effectiveBundleID,
                applicationIdentifier: appID,
                teamPrefixes: teamPrefixes
            )
            if !mainOK {
                issues.append(fatal("APP_ID_MISMATCH", "App ID Mismatch",
                    "Profile App ID '\(appID)' does not cover bundle ID '\(effectiveBundleID)'.",
                    "Choose a matching profile or change the bundle identifier."))
            }

            for mapping in mappings where !mapping.isPrimary {
                let nestedOK = AppIDMatcher.matches(
                    bundleIdentifier: mapping.replacement,
                    applicationIdentifier: appID,
                    teamPrefixes: teamPrefixes
                )
                if !nestedOK {
                    // Wildcard profiles often cover extensions under the same prefix; exact profiles usually don't
                    let pattern = AppIDMatcher.extractAppIDPattern(from: appID) ?? ""
                    if pattern.hasSuffix(".*") {
                        issues.append(warning("NESTED_APP_ID", "Nested Bundle ID Review",
                            "Nested ID '\(mapping.replacement)' should be covered by wildcard '\(appID)'. Verify before signing.",
                            "Confirm the extension IDs follow the main app prefix."))
                    } else {
                        issues.append(fatal("NESTED_PROFILE_REQUIRED", "Separate Profile Required",
                            "Nested bundle '\(mapping.replacement)' is not covered by exact App ID '\(appID)'.",
                            "Use a wildcard App ID profile, or assign a separate profile for this extension."))
                    }
                }
            }
        } else {
            issues.append(fatal("MISSING_APP_ID", "Missing App ID",
                "The provisioning profile does not include an application-identifier entitlement.",
                "Download a complete profile from the Apple Developer portal."))
        }

        // Device rules — informational / warning, never silent claims
        switch profile.profileType {
        case .development, .adHoc:
            if let devices = profile.provisionedDevices {
                issues.append(info("DEVICE_LIST", "Registered Devices",
                    "This \(profile.profileType.rawValue) profile lists \(devices.count) device(s). Installation will only succeed on those devices.",
                    "SignFlow does not automatically register devices."))
            } else {
                issues.append(warning("DEVICE_UNKNOWN", "Device Eligibility Unknown",
                    "This profile type usually requires registered devices, but no device list was found.",
                    "Confirm the profile includes your device UDID before installing."))
            }
        case .enterprise:
            if profile.provisionsAllDevices {
                issues.append(warning("ENTERPRISE_PROFILE", "Enterprise Profile",
                    "This profile provisions all devices. Use only for authorized internal distribution.",
                    "Do not use Enterprise certificates for public distribution."))
            }
        case .appStore:
            issues.append(info("APPSTORE_PROFILE", "App Store Profile",
                "App Store profiles are for App Store submission, not direct device install.",
                "Export the signed IPA for App Store Connect or use a Development/Ad Hoc profile for devices."))
        case .unknown:
            issues.append(warning("UNKNOWN_PROFILE_TYPE", "Unknown Profile Type",
                "Could not classify this provisioning profile type.",
                "Review the profile details carefully before signing."))
        }

        // Entitlements
        let permitted = profileEntitlementsAsAny(profile)
        let requested = package.requestedEntitlements ?? defaultRequested(from: permitted, bundleID: effectiveBundleID, team: profile.teamIdentifier ?? identity.teamIdentifier ?? "")

        let resolution = entitlementResolver.resolve(
            requested: requested,
            permitted: permitted,
            strategy: configuration.entitlementStrategy,
            bundleIdentifier: effectiveBundleID,
            teamIdentifier: profile.teamIdentifier ?? identity.teamIdentifier ?? ""
        )
        issues.append(contentsOf: resolution.issues)

        let entitlementReport = EntitlementReport(
            bundleIdentifier: effectiveBundleID,
            componentPath: nil,
            requestedKeys: Array(requested.keys).sorted(),
            permittedKeys: Array(permitted.keys).sorted(),
            keptKeys: Array(resolution.resolvedEntitlements.keys).sorted(),
            removedKeys: resolution.removedKeys.sorted(),
            issues: resolution.issues
        )

        let canSign = !issues.contains { $0.severity == .fatal }

        return PreflightReport(
            packageSummary: "\(package.displayName) (\(package.primaryBundleIdentifier))",
            identitySummary: "\(identity.displayName) [\(identity.fingerprintSHA256.prefix(12))…]",
            profileSummary: "\(profile.name) (\(profile.profileType.rawValue))",
            bundleIdentifierMappings: mappings,
            entitlementReports: [entitlementReport],
            issues: issues,
            canSign: canSign
        )
    }

    // MARK: - Helpers

    private func profileEntitlementsAsAny(_ profile: ProvisioningProfile) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in profile.entitlements {
            if value == "true" { result[key] = true; continue }
            if value == "false" { result[key] = false; continue }
            if value.contains(", ") {
                result[key] = value.components(separatedBy: ", ")
            } else {
                result[key] = value
            }
        }
        return result
    }

    private func defaultRequested(from permitted: [String: Any], bundleID: String, team: String) -> [String: Any] {
        // When the IPA didn't expose entitlements, treat profile entitlements as the requested set baseline
        var requested = permitted
        requested["application-identifier"] = "\(team).\(bundleID)"
        return requested
    }

    private func fatal(_ code: String, _ title: String, _ explanation: String, _ resolution: String) -> ValidationIssue {
        ValidationIssue(severity: .fatal, code: code, title: title, explanation: explanation, suggestedResolution: resolution)
    }

    private func warning(_ code: String, _ title: String, _ explanation: String, _ resolution: String) -> ValidationIssue {
        ValidationIssue(severity: .warning, code: code, title: title, explanation: explanation, suggestedResolution: resolution)
    }

    private func info(_ code: String, _ title: String, _ explanation: String, _ resolution: String) -> ValidationIssue {
        ValidationIssue(severity: .info, code: code, title: title, explanation: explanation, suggestedResolution: resolution)
    }
}
