import SwiftUI

struct SigningResultView: View {
    let result: SigningJobResult
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var eligibility: InstallationEligibility?
    @State private var installProgress: InstallationProgress?
    @State private var installResult: InstallationResult?
    @State private var installError: String?
    @State private var isInstalling = false
    @State private var installTask: Task<Void, Never>?
    @State private var showShare = false
    @State private var showConsent = false
    @State private var consentChecked = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 76, height: 76)
                        .background(.green, in: RoundedRectangle(cornerRadius: 24))
                    Text("Signing complete")
                        .font(.title2.weight(.bold))
                    Text("The output passed SignFlow's structural verification and is ready to install or export.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }

            Section("Output") {
                LabeledContent("File", value: result.outputFilename)
                LabeledContent("App", value: result.displayName)
                LabeledContent("Bundle ID", value: result.primaryBundleIdentifier)
                LabeledContent("Version", value: result.bundleVersion)
                LabeledContent("SHA-256", value: result.outputSHA256)
                LabeledContent("Signed At", value: result.signedAt.formatted())
            }

            Section("Identity") {
                LabeledContent("Certificate", value: result.identitySummary)
                LabeledContent("Profile", value: result.profileSummary)
                LabeledContent("Profile Type", value: result.profileType.rawValue)
            }

            Section("Verification") {
                LabeledContent("Main App", value: result.verificationReport.mainAppVerified ? "Verified" : "Failed")
                LabeledContent("Profile Embedded", value: result.verificationReport.profileEmbedded ? "Yes" : "No")
                LabeledContent("Overall", value: result.verificationReport.overallStatus ? "Passed" : "Failed")
            }

            if !result.warnings.isEmpty {
                Section("Warnings") {
                    ForEach(result.warnings) { warning in
                        Text(warning.title).font(.subheadline.bold())
                        Text(warning.explanation).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Install") {
                if let eligibility {
                    Text(eligibility.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    switch eligibility {
                    case .hostedOTA:
                        Button {
                            showConsent = true
                        } label: {
                            if isInstalling {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label("Install on This Device", systemImage: "iphone.and.arrow.forward")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SignFlowTheme.accent)
                        .disabled(isInstalling)

                        if isInstalling {
                            Button("Cancel Upload", role: .destructive) {
                                installTask?.cancel()
                                isInstalling = false
                                installProgress = nil
                                installError = "Installation cancelled."
                            }
                        }

                    case .externalHandoff:
                        Button {
                            showShare = true
                        } label: {
                            Label("Open in Installer / Share IPA", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(SignFlowTheme.accent)

                        Text("Free/development builds cannot use Apple OTA. Share the IPA with AltStore, SideStore, Xcode, or Apple Configurator.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                    case .unavailable:
                        Text("Direct installation is not available for this profile type.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView("Checking installation options…")
                }

                if let installProgress {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: installProgress.fractionCompleted)
                        Text(installProgress.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let installResult {
                    Label(installResult.message, systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if let installError {
                    Text(installError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Export") {
                Button {
                    showShare = true
                } label: {
                    Label("Export / Share IPA", systemImage: "square.and.arrow.up")
                }
            }

            Section {
                Button("Done") {
                    router.popToRoot()
                }
            }
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [result.outputURL])
        }
        .sheet(isPresented: $showConsent) {
            InstallationConsentSheet(
                appName: result.displayName,
                consentChecked: $consentChecked
            ) {
                showConsent = false
                InstallerSettings.retentionAcknowledged = true
                startInstall()
            } onCancel: {
                showConsent = false
            }
        }
        .task {
            eligibility = await environment.appInstaller.eligibility(for: result.installationRequest())
            if SignFlowPreferences.signingOptions.installAfterSigning,
               case .hostedOTA = eligibility {
                showConsent = true
            } else if SignFlowPreferences.showShareSheetOnExport {
                showShare = true
            }
        }
    }

    private func startInstall() {
        installError = nil
        installResult = nil
        isInstalling = true
        installTask = Task {
            do {
                let outcome = try await environment.appInstaller.install(
                    request: result.installationRequest()
                ) { progress in
                    Task { @MainActor in
                        installProgress = progress
                    }
                }
                await MainActor.run {
                    installResult = outcome
                    isInstalling = false
                    if outcome.kind == .externalShare {
                        showShare = true
                    }
                }
            } catch is CancellationError {
                await MainActor.run {
                    isInstalling = false
                    installError = "Installation cancelled."
                }
            } catch let error as SignFlowError {
                await MainActor.run {
                    isInstalling = false
                    installError = error.explanation
                }
            } catch {
                await MainActor.run {
                    isInstalling = false
                    installError = error.localizedDescription
                }
            }
        }
    }
}

private struct InstallationConsentSheet: View {
    let appName: String
    @Binding var consentChecked: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("SignFlow will temporarily upload “\(appName)” to your private Cloudflare installer so iOS can fetch it over HTTPS.")
                    Text("The upload is deleted after download or when the retention window expires. Certificates and private keys are never uploaded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Toggle("I understand this temporary upload", isOn: $consentChecked)
                }
            }
            .navigationTitle("Install Consent")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Install") {
                        onConfirm()
                    }
                    .disabled(!consentChecked)
                }
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
