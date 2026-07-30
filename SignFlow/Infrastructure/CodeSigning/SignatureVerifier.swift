import Foundation
import OSLog

struct SignatureVerifier: SignatureVerifying {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "SignatureVerifier")

    func verify(appBundleURL: URL, expectedProfileUUID: String?) async throws -> VerificationReport {
        try Task.checkCancellation()
        var issues: [ValidationIssue] = []
        var nestedItems: [NestedVerificationItem] = []

        let codeSig = appBundleURL.appendingPathComponent("_CodeSignature/CodeResources")
        let mainVerified = FileManager.default.fileExists(atPath: codeSig.path)
        if !mainVerified {
            issues.append(ValidationIssue(
                severity: .fatal,
                code: "MAIN_UNSIGNED",
                title: "Main App Not Signed",
                explanation: "The main application is missing _CodeSignature/CodeResources after signing.",
                suggestedResolution: "Re-run signing and check the signing log."
            ))
        }

        let profileURL = appBundleURL.appendingPathComponent("embedded.mobileprovision")
        let profileEmbedded = FileManager.default.fileExists(atPath: profileURL.path)
        if expectedProfileUUID != nil && !profileEmbedded {
            issues.append(ValidationIssue(
                severity: .fatal,
                code: "PROFILE_NOT_EMBEDDED",
                title: "Profile Not Embedded",
                explanation: "embedded.mobileprovision is missing from the signed app.",
                suggestedResolution: "Ensure a provisioning profile was selected and signing completed."
            ))
        } else if let expectedProfileUUID, profileEmbedded {
            if let data = try? Data(contentsOf: profileURL),
               let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
               !text.contains(expectedProfileUUID) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    code: "PROFILE_UUID_UNCONFIRMED",
                    title: "Profile UUID Unconfirmed",
                    explanation: "Could not confirm the embedded profile UUID matches the selected profile.",
                    suggestedResolution: "Inspect the signed IPA if installation fails."
                ))
            }
        }

        for subdir in ["Frameworks", "PlugIns", "Watch"] {
            let dir = appBundleURL.appendingPathComponent(subdir)
            guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for item in items {
                let sig = item.appendingPathComponent("_CodeSignature/CodeResources")
                let ok = FileManager.default.fileExists(atPath: sig.path)
                    || item.pathExtension == "dylib"
                nestedItems.append(NestedVerificationItem(path: item.lastPathComponent, verified: ok))
                if !ok && (item.pathExtension == "framework" || item.pathExtension == "appex" || item.pathExtension == "app") {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        code: "NESTED_UNSIGNED",
                        title: "Nested Component May Be Unsigned",
                        explanation: "\(item.lastPathComponent) does not show a CodeResources file.",
                        suggestedResolution: "Verify nested signing order if the app fails to launch."
                    ))
                }
            }
        }

        let structureOK = FileManager.default.fileExists(
            atPath: appBundleURL.appendingPathComponent("Info.plist").path
        )

        let profileOK = expectedProfileUUID == nil || profileEmbedded
        let overall = mainVerified && profileOK && structureOK && !issues.contains { $0.severity == .fatal }
        Self.logger.info("Verification overall=\(overall, privacy: .public)")

        return VerificationReport(
            mainAppVerified: mainVerified,
            nestedComponents: nestedItems,
            profileEmbedded: profileEmbedded,
            packageStructureVerified: structureOK,
            issues: issues,
            overallStatus: overall
        )
    }
}
