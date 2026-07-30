import Foundation
import OSLog
#if canImport(Zupersign)
import Zupersign
#endif

final class ZSignCodeSigner: CodeSigning, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "ZSignCodeSigner")

    func signAppBundle(
        at appURL: URL,
        identity: SigningIdentity,
        profile: ProvisioningProfile,
        entitlementPlists: [String: Data],
        embedProvisioningProfile: Bool,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        try Task.checkCancellation()

        let embedded = appURL.appendingPathComponent("embedded.mobileprovision")
        if FileManager.default.fileExists(atPath: embedded.path) {
            try FileManager.default.removeItem(at: embedded)
        }
        if embedProvisioningProfile {
            let profileURL = try resolveProfileFile(for: profile)
            try FileManager.default.copyItem(at: profileURL, to: embedded)
        }

        progress(0.1, "Exporting signing identity")
        let material = try SigningIdentityExporter.export(identity: identity)

        progress(0.2, "Preparing entitlements")
        let entitlementsData = entitlementPlists["."] ?? entitlementPlists.values.first
        guard let entitlementsData else {
            throw SignFlowError.signingFailed(detail: "No entitlements were resolved for the main application.")
        }

        progress(0.3, "Signing with zsign")
        try await signWithZSign(
            appURL: appURL,
            certificateDER: material.certificateDER,
            privateKeyPEM: material.privateKeyPEM,
            entitlements: entitlementsData,
            progress: progress
        )
        progress(1.0, "Signing complete")
    }

    private func signWithZSign(
        appURL: URL,
        certificateDER: Data,
        privateKeyPEM: Data,
        entitlements: Data,
        progress: @escaping @Sendable (Double, String) -> Void
    ) async throws {
        #if canImport(Zupersign)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let appPath = appURL.path
                var exception: UnsafeMutablePointer<CChar>?

                let progressBox = ProgressBox(handler: progress)
                let progressContext = Unmanaged.passRetained(progressBox).toOpaque()
                defer { Unmanaged<ProgressBox>.fromOpaque(progressContext).release() }

                let result: Int32 = certificateDER.withUnsafeBytes { certBuf in
                    privateKeyPEM.withUnsafeBytes { keyBuf in
                        entitlements.withUnsafeBytes { entsBuf in
                            guard let certPtr = certBuf.baseAddress,
                                  let keyPtr = keyBuf.baseAddress,
                                  let entsPtr = entsBuf.baseAddress else {
                                return Int32(-1)
                            }
                            var ents = entitlements_data_t(
                                bundle_path: ".",
                                data: entsPtr,
                                len: entsBuf.count
                            )
                            return zsign_sign(
                                appPath,
                                certPtr,
                                certBuf.count,
                                keyPtr,
                                keyBuf.count,
                                &ents,
                                1,
                                { ctx, value in
                                    let box = Unmanaged<ProgressBox>.fromOpaque(ctx).takeUnretainedValue()
                                    box.handler(value, "Signing…")
                                },
                                progressContext,
                                &exception
                            )
                        }
                    }
                }

                if result == -1 && exception == nil {
                    continuation.resume(throwing: SignFlowError.signingFailed(detail: "Could not access signing buffers."))
                    return
                }

                if result != 0 {
                    let message = exception.map { String(cString: $0) } ?? "Unknown zsign error"
                    if let exception { free(exception) }
                    continuation.resume(throwing: SignFlowError.signingFailed(detail: message))
                } else {
                    if let exception { free(exception) }
                    continuation.resume()
                }
            }
        }
        #else
        throw SignFlowError.signingFailed(detail: "Zupersign is not linked. Add the zsign package dependency and rebuild.")
        #endif
    }

    private func resolveProfileFile(for profile: ProvisioningProfile) throws -> URL {
        var candidates: [URL] = []

        if let canonical = try? ProvisioningProfileStore.canonicalFileURL(forUUID: profile.uuid) {
            candidates.append(canonical)
        }

        if let stored = profile.filePath {
            if stored.hasPrefix("/") {
                let storedURL = URL(fileURLWithPath: stored)
                if !candidates.contains(where: { $0.path == storedURL.path }) {
                    candidates.append(storedURL)
                }
            } else if let canonical = try? ProvisioningProfileStore.canonicalFileURL(forUUID: profile.uuid) {
                let sibling = canonical.deletingLastPathComponent().appendingPathComponent(stored)
                if !candidates.contains(where: { $0.path == sibling.path }) {
                    candidates.append(sibling)
                }
            }
        }

        if let match = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            return match
        }

        throw SignFlowError.signingFailed(
            detail: "Provisioning profile file is missing from storage. Re-import the .mobileprovision file."
        )
    }
}

private final class ProgressBox: @unchecked Sendable {
    let handler: @Sendable (Double, String) -> Void
    init(handler: @escaping @Sendable (Double, String) -> Void) {
        self.handler = handler
    }
}
