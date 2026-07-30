import SwiftUI

struct InspectionProgressView: View {
    let sourceURL: URL
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var stage: InspectionStage = .copying
    @State private var error: SignFlowError?
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 24) {
            if let error {
                errorView(error)
            } else {
                progressView
            }
        }
        .padding()
        .navigationTitle("Inspecting")
        .navigationBarBackButtonHidden(error == nil)
        .toolbar {
            if error == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        task?.cancel()
                        router.pop()
                    }
                }
            }
        }
        .task {
            let t = Task {
                await runInspection()
            }
            task = t
            await t.value
        }
    }

    private var progressView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(stage.description)
                .font(.headline)

            Text(stage.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func errorView(_ error: SignFlowError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text(error.title)
                .font(.title3.bold())

            Text(error.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(error.suggestedResolution)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button("Go Back") {
                router.pop()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func runInspection() async {
        do {
            stage = .copying
            let workspace = try await environment.workspaceManager.createWorkspace()

            defer {
                if error != nil {
                    Task { try? await environment.workspaceManager.removeWorkspace(workspace) }
                }
            }

            let importResult = try await environment.ipaImporter.importIPA(from: sourceURL, workspace: workspace)

            stage = .extracting
            let extractionDir = workspace.appendingPathComponent("extracted", isDirectory: true)
            _ = try await environment.ipaExtractor.extract(
                archiveURL: importResult.copiedFileURL,
                to: extractionDir,
                limits: .default
            )

            stage = .inspecting
            var package = try await environment.ipaInspector.inspect(extractedPayloadURL: extractionDir)

            // Persist IPA outside the temporary workspace for later signing
            let importsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Imports", isDirectory: true)
            try FileManager.default.createDirectory(at: importsDir, withIntermediateDirectories: true)
            let durableIPA = importsDir.appendingPathComponent(importResult.originalFilename)
            if FileManager.default.fileExists(atPath: durableIPA.path) {
                try FileManager.default.removeItem(at: durableIPA)
            }
            try FileManager.default.copyItem(at: importResult.copiedFileURL, to: durableIPA)

            package = AppPackage(
                id: package.id,
                sourceURL: durableIPA,
                originalFilename: importResult.originalFilename,
                sha256: importResult.sha256,
                fileSize: importResult.fileSize,
                applicationBundleURL: package.applicationBundleURL,
                displayName: package.displayName,
                executableName: package.executableName,
                primaryBundleIdentifier: package.primaryBundleIdentifier,
                version: package.version,
                buildNumber: package.buildNumber,
                minimumOSVersion: package.minimumOSVersion,
                architectures: package.architectures,
                nestedBundles: package.nestedBundles,
                embeddedProvisioningProfile: package.embeddedProvisioningProfile,
                requestedEntitlements: package.requestedEntitlements,
                inspectionWarnings: package.inspectionWarnings,
                existingSignatureStatus: package.existingSignatureStatus
            )

            // Clean inspection workspace; durable IPA remains
            try? await environment.workspaceManager.removeWorkspace(workspace)

            stage = .complete
            await MainActor.run {
                environment.rememberInspected(package)
                router.pop()
                router.navigate(to: .appDetails(package))
            }

        } catch is CancellationError {
            error = .userCancelled
        } catch let sfError as SignFlowError {
            error = sfError
        } catch {
            self.error = .internalError(detail: error.localizedDescription)
        }
    }
}

enum InspectionStage {
    case copying
    case extracting
    case inspecting
    case complete

    var description: String {
        switch self {
        case .copying:    return "Copying File"
        case .extracting: return "Extracting Archive"
        case .inspecting: return "Inspecting Application"
        case .complete:   return "Complete"
        }
    }

    var detail: String {
        switch self {
        case .copying:    return "Copying the IPA to a secure workspace..."
        case .extracting: return "Extracting and validating archive contents..."
        case .inspecting: return "Reading application metadata and structure..."
        case .complete:   return "Inspection complete."
        }
    }
}
