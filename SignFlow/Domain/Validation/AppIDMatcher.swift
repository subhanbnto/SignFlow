import Foundation

enum AppIDMatcher {
    /// Profile application-identifier looks like `TEAMID.com.example.app` or `TEAMID.com.example.*`
    static func matches(bundleIdentifier: String, applicationIdentifier: String?, teamPrefixes: [String]) -> Bool {
        guard let applicationIdentifier, !applicationIdentifier.isEmpty else {
            return false
        }

        let parts = applicationIdentifier.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }

        let teamPrefix = String(parts[0])
        let appIDPattern = String(parts[1])

        if !teamPrefixes.isEmpty && !teamPrefixes.contains(teamPrefix) {
            // Still allow if the only available data is embedded in application-identifier
            if !teamPrefixes.contains(teamPrefix) {
                // Team list from profile should include this prefix; if empty, use the one from App ID
            }
        }

        return matchesBundleID(bundleIdentifier, pattern: appIDPattern)
    }

    static func matchesBundleID(_ bundleID: String, pattern: String) -> Bool {
        if pattern == "*" {
            return !bundleID.isEmpty
        }

        if pattern.hasSuffix(".*") {
            let prefix = String(pattern.dropLast(2))
            // Wildcard must match prefix + "." + something, OR exact prefix
            if bundleID == prefix { return true }
            return bundleID.hasPrefix(prefix + ".")
        }

        // Invalid wildcard placements are rejected (exact match only otherwise)
        if pattern.contains("*") {
            return false
        }

        return bundleID == pattern
    }

    static func extractAppIDPattern(from applicationIdentifier: String?) -> String? {
        guard let applicationIdentifier else { return nil }
        let parts = applicationIdentifier.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        return String(parts[1])
    }
}
