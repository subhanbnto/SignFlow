import Foundation
import OSLog

actor SigningOrchestrator: SigningOrchestrating {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "SigningOrchestrator")

    private let workspaceManager: any TemporaryFileManaging
    private let extractor: any IPAExtracting
    private let inspector: any IPAInspecting
    private let rewriter: BundleIdentifierRewriting
    private let entitlementResolver: EntitlementResolving
    private let orderPlanner: SigningOrderPlanning
    private let codeSigner: any CodeSigning
    private let verifier: any SignatureVerifying
    private let repackager: any IPARepackaging
    private let preflight: any SigningAssetValidating
    private let appModifier: any AppModifying
    private let tweakInjector: any TweakInjecting

    init(
        workspaceManager: any TemporaryFileManaging = WorkspaceManager(),
        extractor: any IPAExtracting = SafeZIPExtractor(),
        inspector: any IPAInspecting = IPAInspector(),
        rewriter: BundleIdentifierRewriting = BundleIdentifierRewriter(),
        entitlementResolver: EntitlementResolving = EntitlementResolver(),
        orderPlanner: SigningOrderPlanning = SigningOrderPlanner(),
        codeSigner: any CodeSigning = ZSignCodeSigner(),
        verifier: any SignatureVerifying = SignatureVerifier(),
        repackager: any IPARepackaging = IPARepackager(),
        preflight: any SigningAssetValidating = PreflightValidator(),
        appModifier: any AppModifying = AppModifier(),
        tweakInjector: any TweakInjecting = TweakInjector()
    ) {
        self.workspaceManager = workspaceManager
        self.extractor = extractor
        self.inspector = inspector
        self.rewriter = rewriter
        self.entitlementResolver = entitlementResolver
        self.orderPlanner = orderPlanner
        self.codeSigner = codeSigner
        self.verifier = verifier
        self.repackager = repackager
        self.preflight = preflight
        self.appModifier = appModifier
        self.tweakInjector = tweakInjector
    }

    func sign(
        configuration: SigningConfiguration,
        progressHandler: @escaping @Sendable (SigningProgress) -> Void
    ) async throws -> SigningJobResult {
        let started = Date()
        var progress = SigningProgress(
            currentStage: .preparing,
            completedUnits: 0,
            totalUnits: 12,
            currentComponent: nil,
            recentMessage: "Preparing…",
            startedAt: started
        )

        func emit(_ stage: SigningProgress.Stage, message: String, component: String? = nil) {
            progress.currentStage = stage
            progress.recentMessage = message
            progress.currentComponent = component
            progress.completedUnits = min(progress.totalUnits, progress.completedUnits + 1)
            progressHandler(progress)
        }

        let workspace = try await workspaceManager.createWorkspace()
        do {
            emit(.preparing, message: "Created signing workspace")

            // Copy original IPA into workspace
            let ipaCopy = workspace.appendingPathComponent(configuration.package.originalFilename)
            if configuration.package.sourceURL.path != ipaCopy.path {
                if FileManager.default.fileExists(atPath: configuration.package.sourceURL.path) {
                    try FileManager.default.copyItem(at: configuration.package.sourceURL, to: ipaCopy)
                } else {
                    throw SignFlowError.invalidIPA(detail: "Original IPA is no longer available. Re-import the IPA.")
                }
            }

            emit(.extracting, message: "Extracting IPA")
            let extractDir = workspace.appendingPathComponent("extracted", isDirectory: true)
            _ = try await extractor.extract(archiveURL: ipaCopy, to: extractDir, limits: .default)

            let payloadParent = try locatePayloadParent(in: extractDir)
            let payloadURL = payloadParent.appendingPathComponent("Payload")
            let apps = try FileManager.default.contentsOfDirectory(at: payloadURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "app" }
            guard let appURL = apps.first else {
                throw SignFlowError.missingPrimaryApplication
            }

            emit(.inspecting, message: "Planning nested signing order")
            let nested = try await discoverNested(appURL: appURL)
            let units = orderPlanner.planSigningOrder(appURL: appURL, nestedBundles: nested)
            _ = units

            emit(.resolvingIdentifiers, message: "Applying bundle identifier mappings")
            let mappings = rewriter.computeMappings(
                original: configuration.package.primaryBundleIdentifier,
                replacement: configuration.effectiveBundleIdentifier,
                nestedBundles: nested
            )
            try await rewriter.applyMappings(mappings: mappings, toAppBundle: appURL)

            // Display name
            if configuration.effectiveDisplayName != configuration.package.displayName {
                try updateDisplayName(configuration.effectiveDisplayName, in: appURL)
            }

            emit(.resolvingEntitlements, message: "Applying app modifications")
            try await appModifier.apply(
                options: configuration.options,
                toAppBundle: appURL,
                displayName: configuration.effectiveDisplayName
            )

            let tweakURLs = configuration.options.tweakPaths.map { URL(fileURLWithPath: $0) }
            if !tweakURLs.isEmpty {
                try await tweakInjector.inject(
                    tweakURLs: tweakURLs,
                    intoAppBundle: appURL,
                    intoExtensions: configuration.options.injectIntoExtensions
                )
            }

            emit(.resolvingEntitlements, message: "Resolving entitlements")
            let permitted = flattenProfileEntitlements(configuration.profile)
            let requested = configuration.package.requestedEntitlements ?? permitted
            let resolution = entitlementResolver.resolve(
                requested: requested,
                permitted: permitted,
                strategy: configuration.entitlementStrategy,
                bundleIdentifier: configuration.effectiveBundleIdentifier,
                teamIdentifier: configuration.profile.teamIdentifier
                    ?? configuration.identity.teamIdentifier
                    ?? ""
            )
            if configuration.entitlementStrategy == .strict,
               resolution.issues.contains(where: { $0.severity == .fatal }) {
                throw SignFlowError.unsupportedEntitlement(key: resolution.removedKeys.first ?? "unknown")
            }

            let entitlementsData = try PropertyListSerialization.data(
                fromPropertyList: resolution.resolvedEntitlements,
                format: .xml,
                options: 0
            )

            emit(.embeddingProfiles, message: "Embedding profile and signing")
            try await codeSigner.signAppBundle(
                at: appURL,
                identity: configuration.identity,
                profile: configuration.profile,
                entitlementPlists: [".": entitlementsData],
                embedProvisioningProfile: !configuration.options.removeProvisioning
            ) { fraction, message in
                var p = progress
                p.recentMessage = message
                p.currentStage = .signingMainApp
                progressHandler(p)
            }

            emit(.verifying, message: "Verifying signatures")
            let verification = try await verifier.verify(
                appBundleURL: appURL,
                expectedProfileUUID: configuration.options.removeProvisioning ? nil : configuration.profile.uuid
            )
            if !verification.overallStatus {
                throw SignFlowError.signatureVerificationFailed(
                    component: "main app",
                    detail: verification.issues.first?.explanation ?? "Verification failed."
                )
            }

            emit(.packaging, message: "Packaging signed IPA")
            let outputName = configuration.outputFilename.hasSuffix(".ipa")
                ? configuration.outputFilename
                : configuration.outputFilename + ".ipa"
            let outputURL = workspace.appendingPathComponent(outputName)
            _ = try await repackager.repackage(
                payloadParentURL: payloadParent,
                outputURL: outputURL,
                compressionLevel: SignFlowPreferences.compressionLevel
            )

            // Move to a durable exports directory
            let exports = try exportsDirectory()
            let finalURL = exports.appendingPathComponent(outputName)
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
            }
            try FileManager.default.copyItem(at: outputURL, to: finalURL)

            emit(.hashing, message: "Hashing output")
            let hash = try await SHA256Hasher.hash(fileAt: finalURL)
            let attributes = try FileManager.default.attributesOfItem(atPath: finalURL.path)
            let byteSize = (attributes[.size] as? NSNumber)?.uint64Value ?? 0

            emit(.cleaning, message: "Cleaning workspace")
            try await workspaceManager.removeWorkspace(workspace)

            progress.currentStage = .complete
            progress.recentMessage = "Signed successfully"
            progress.completedUnits = progress.totalUnits
            progressHandler(progress)

            return SigningJobResult(
                id: UUID(),
                outputURL: finalURL,
                outputSHA256: hash,
                signedAt: Date(),
                finalBundleIdentifiers: mappings.map(\.replacement),
                identitySummary: configuration.identity.displayName,
                profileSummary: configuration.profile.name,
                verificationReport: verification,
                warnings: verification.issues.filter { $0.severity == .warning },
                outputFilename: outputName,
                displayName: configuration.effectiveDisplayName,
                bundleVersion: configuration.package.version,
                primaryBundleIdentifier: configuration.effectiveBundleIdentifier,
                profileType: configuration.profile.profileType,
                byteSize: byteSize
            )
        } catch {
            try? await workspaceManager.removeWorkspace(workspace)
            progress.currentStage = .failed
            progress.recentMessage = (error as? SignFlowError)?.explanation ?? error.localizedDescription
            progressHandler(progress)
            throw error
        }
    }

    // MARK: - Helpers

    private func locatePayloadParent(in extractDir: URL) throws -> URL {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for item in contents {
            if item.lastPathComponent == "Payload" { return extractDir }
            if fm.fileExists(atPath: item.appendingPathComponent("Payload").path) {
                return item
            }
        }
        // Direct Payload
        if fm.fileExists(atPath: extractDir.appendingPathComponent("Payload").path) {
            return extractDir
        }
        throw SignFlowError.missingPayloadDirectory
    }

    private func discoverNested(appURL: URL) async throws -> [NestedBundle] {
        // Reuse inspector on a temporary synthetic root is heavy; walk like IPAInspector
        var bundles: [NestedBundle] = []
        let fm = FileManager.default

        let frameworks = appURL.appendingPathComponent("Frameworks")
        if let items = try? fm.contentsOfDirectory(at: frameworks, includingPropertiesForKeys: nil) {
            for item in items {
                let type: NestedBundleType = item.pathExtension == "framework" ? .framework : .dynamicLibrary
                bundles.append(NestedBundle(
                    id: UUID(), type: type,
                    relativePath: "Frameworks/\(item.lastPathComponent)",
                    bundleIdentifier: item.deletingPathExtension().lastPathComponent,
                    executableName: nil, version: nil,
                    parentBundleIdentifier: nil, nestedComponents: []
                ))
            }
        }

        let plugins = appURL.appendingPathComponent("PlugIns")
        if let items = try? fm.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil) {
            for item in items where item.pathExtension == "appex" {
                var bundleID = item.deletingPathExtension().lastPathComponent
                var exec: String?
                if let info = try? PlistParser.parseInfoPlist(at: item.appendingPathComponent("Info.plist")) {
                    bundleID = info.bundleIdentifier
                    exec = info.executableName
                }
                bundles.append(NestedBundle(
                    id: UUID(), type: .appExtension,
                    relativePath: "PlugIns/\(item.lastPathComponent)",
                    bundleIdentifier: bundleID,
                    executableName: exec, version: nil,
                    parentBundleIdentifier: nil, nestedComponents: []
                ))
            }
        }
        return bundles
    }

    private func updateDisplayName(_ name: String, in appURL: URL) throws {
        let infoURL = appURL.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoURL)
        guard var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw SignFlowError.malformedInfoPlist(detail: "Could not update display name.")
        }
        plist["CFBundleDisplayName"] = name
        let out = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try out.write(to: infoURL, options: .atomic)
    }

    private func flattenProfileEntitlements(_ profile: ProvisioningProfile) -> [String: Any] {
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

    private func exportsDirectory() throws -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
