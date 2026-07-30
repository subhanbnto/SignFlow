import Foundation

struct EntitlementResolver: EntitlementResolving {
    /// Keys that must be rewritten to match team / bundle rather than copied blindly.
    static let managedKeys: Set<String> = [
        "application-identifier",
        "com.apple.developer.team-identifier",
        "keychain-access-groups",
        "com.apple.security.application-groups"
    ]

    func resolve(
        requested: [String: Any],
        permitted: [String: Any],
        strategy: EntitlementStrategy,
        bundleIdentifier: String,
        teamIdentifier: String
    ) -> EntitlementResolutionResult {
        var issues: [ValidationIssue] = []
        var resolved: [String: Any] = [:]
        var removed: [String] = []

        let permittedKeys = Set(permitted.keys)

        // Always set managed identity entitlements from profile + requested IDs
        if let appID = permitted["application-identifier"] as? String {
            resolved["application-identifier"] = rewriteApplicationIdentifier(
                profileValue: appID,
                bundleIdentifier: bundleIdentifier,
                teamIdentifier: teamIdentifier
            )
        } else if permittedKeys.contains("application-identifier") {
            resolved["application-identifier"] = "\(teamIdentifier).\(bundleIdentifier)"
        }

        if permitted["com.apple.developer.team-identifier"] != nil || !teamIdentifier.isEmpty {
            resolved["com.apple.developer.team-identifier"] = teamIdentifier
        }

        for (key, value) in requested {
            if Self.managedKeys.contains(key) {
                continue
            }

            if permittedKeys.contains(key) {
                // Prefer profile-permitted value when it's a constrained string/array; otherwise keep requested if compatible
                if let permittedValue = permitted[key] {
                    resolved[key] = intersectValue(requested: value, permitted: permittedValue, key: key, issues: &issues)
                }
            } else {
                removed.append(key)
                switch strategy {
                case .strict:
                    issues.append(ValidationIssue(
                        severity: .fatal,
                        code: "UNSUPPORTED_ENTITLEMENT",
                        title: "Unsupported Entitlement",
                        explanation: "The entitlement '\(key)' is not permitted by the selected provisioning profile.",
                        suggestedResolution: "Remove the capability from the app, or use a profile that includes it.",
                        affectedBundleIdentifier: bundleIdentifier
                    ))
                case .permittedSubset, .advancedReview:
                    issues.append(ValidationIssue(
                        severity: strategy == .advancedReview ? .warning : .warning,
                        code: "ENTITLEMENT_REMOVED",
                        title: "Entitlement Will Be Removed",
                        explanation: "The entitlement '\(key)' is not permitted by the profile and will not be included.",
                        suggestedResolution: "Confirm this is acceptable, or choose a different profile.",
                        affectedBundleIdentifier: bundleIdentifier
                    ))
                }
            }
        }

        // Include remaining permitted keys that are typically required even if not in requested set
        for (key, value) in permitted where !Self.managedKeys.contains(key) && resolved[key] == nil {
            if key == "get-task-allow" {
                resolved[key] = value
            }
        }

        if strategy == .strict && !removed.isEmpty && issues.contains(where: { $0.severity == .fatal }) {
            // already recorded
        }

        return EntitlementResolutionResult(
            resolvedEntitlements: resolved,
            removedKeys: removed,
            issues: issues
        )
    }

    func rewriteApplicationIdentifier(profileValue: String, bundleIdentifier: String, teamIdentifier: String) -> String {
        let parts = profileValue.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let team = parts.isEmpty ? teamIdentifier : String(parts[0])
        if profileValue.hasSuffix(".*") || (parts.count == 2 && parts[1].hasSuffix(".*")) {
            return "\(team).\(bundleIdentifier)"
        }
        // Exact App ID — keep profile value
        return profileValue
    }

    private func intersectValue(
        requested: Any,
        permitted: Any,
        key: String,
        issues: inout [ValidationIssue]
    ) -> Any {
        if let reqArray = requested as? [String], let permArray = permitted as? [String] {
            let allowed = Set(permArray)
            let kept = reqArray.filter { allowed.contains($0) || matchesWildcard($0, in: permArray) }
            let dropped = reqArray.filter { !kept.contains($0) }
            if !dropped.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "ENTITLEMENT_VALUES_TRIMMED",
                    title: "Entitlement Values Trimmed",
                    explanation: "Some values for '\(key)' are not permitted: \(dropped.joined(separator: ", ")).",
                    suggestedResolution: "Update the profile or remove those values from the app."
                ))
            }
            return kept.isEmpty ? permArray : kept
        }
        // Prefer permitted scalar when both exist
        return permitted
    }

    private func matchesWildcard(_ value: String, in permitted: [String]) -> Bool {
        for pattern in permitted where pattern.hasSuffix(".*") {
            let prefix = String(pattern.dropLast(2))
            if value == prefix || value.hasPrefix(prefix + ".") {
                return true
            }
        }
        return false
    }
}
