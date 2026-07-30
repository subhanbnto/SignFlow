import SwiftUI

struct SigningSetupView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    var preselectedLibraryApp: LibraryAppRecord?

    @State private var packages: [AppPackage] = []
    @State private var identities: [SigningIdentity] = []
    @State private var profiles: [ProvisioningProfile] = []

    @State private var selectedPackageID: UUID?
    @State private var selectedIdentityID: UUID?
    @State private var selectedProfileID: UUID?
    @State private var displayName: String = ""
    @State private var bundleID: String = ""
    @State private var strategy: EntitlementStrategy = .permittedSubset
    @State private var outputFilename: String = ""
    @State private var options = SignFlowPreferences.signingOptions
    @State private var isPreparing = false
    @State private var errorMessage: String?
    @State private var showTweaksImporter = false

    private var selectedPackage: AppPackage? {
        packages.first { $0.id == selectedPackageID }
    }

    private var selectedIdentity: SigningIdentity? {
        identities.first { $0.id == selectedIdentityID }
    }

    private var selectedProfile: ProvisioningProfile? {
        profiles.first { $0.id == selectedProfileID }
    }

    private var canContinue: Bool {
        selectedPackage != nil && selectedIdentity != nil && selectedProfile != nil && !isPreparing
    }

    var body: some View {
        Form {
            Section {
                if let preselectedLibraryApp, selectedPackage == nil {
                    LabeledContent("App", value: preselectedLibraryApp.displayName)
                    if isPreparing {
                        ProgressView("Preparing app for signing…")
                    }
                } else if packages.isEmpty {
                    missingAsset("No imported apps", actionTitle: "Import IPA") {
                        router.navigate(to: .importIPA)
                    }
                } else {
                    Picker("Application", selection: $selectedPackageID) {
                        Text("Select an app").tag(Optional<UUID>.none)
                        ForEach(packages) { package in
                            Text(package.displayName).tag(Optional(package.id))
                        }
                    }
                }
            } header: {
                Text("Application")
            }

            Section {
                if identities.isEmpty {
                    missingAsset("No signing certificate", actionTitle: "Import P12") {
                        router.navigate(to: .importCertificate)
                    }
                } else {
                    Picker("Certificate", selection: $selectedIdentityID) {
                        Text("Select a certificate").tag(Optional<UUID>.none)
                        ForEach(identities) { identity in
                            Text(identity.displayName).tag(Optional(identity.id))
                        }
                    }
                }

                if profiles.isEmpty {
                    missingAsset("No provisioning profile", actionTitle: "Import Profile") {
                        router.navigate(to: .importProfile)
                    }
                } else {
                    Picker("Profile", selection: $selectedProfileID) {
                        Text("Select a profile").tag(Optional<UUID>.none)
                        ForEach(profiles) { profile in
                            Text(profile.name).tag(Optional(profile.id))
                        }
                    }
                }
            } header: {
                Text("Signing")
            }

            Section("Properties") {
                TextField("Display name", text: $displayName)
                TextField("Bundle identifier", text: $bundleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Output filename", text: $outputFilename)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Entitlements", selection: $strategy) {
                    ForEach(EntitlementStrategy.allCases, id: \.self) { item in
                        Text(item.displayName).tag(item)
                    }
                }
            }

            DisclosureGroup("Advanced") {
                SigningOptionsForm(options: $options)
                Section {
                    Button("Add Tweaks (.dylib)") {
                        showTweaksImporter = true
                    }
                    if !options.tweakPaths.isEmpty {
                        ForEach(options.tweakPaths, id: \.self) { path in
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .font(.caption)
                        }
                        Button("Clear Tweaks", role: .destructive) {
                            options.tweakPaths = []
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }
            }

            Section {
                Button {
                    continueToPreflight()
                } label: {
                    Label("Continue", systemImage: "checkmark.shield")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!canContinue)
            }
        }
        .tint(SignFlowTheme.accent)
        .navigationTitle("Sign App")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .onChange(of: selectedPackageID) { _, _ in
            if let package = selectedPackage {
                if displayName.isEmpty { displayName = package.displayName }
                if bundleID.isEmpty { bundleID = package.primaryBundleIdentifier }
                if outputFilename.isEmpty { outputFilename = "\(package.displayName)-signed.ipa" }
            }
        }
        .fileImporter(
            isPresented: $showTweaksImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                let dylibs = urls.filter { $0.pathExtension.lowercased() == "dylib" || $0.pathExtension.lowercased() == "deb" }
                options.tweakPaths.append(contentsOf: dylibs.map(\.path))
            }
        }
    }

    private func reload() async {
        packages = environment.inspectedPackages
        identities = (try? await environment.certificateStore.listIdentities()) ?? []
        profiles = (try? await environment.profileStore.listProfiles()) ?? []

        if let storedIdentity = UserDefaults.standard.string(forKey: SignFlowPreferences.selectedIdentityIDKey),
           let id = UUID(uuidString: storedIdentity),
           identities.contains(where: { $0.id == id }) {
            selectedIdentityID = id
        } else if selectedIdentityID == nil {
            selectedIdentityID = identities.first?.id
        }

        if let storedProfile = UserDefaults.standard.string(forKey: SignFlowPreferences.selectedProfileIDKey),
           let id = UUID(uuidString: storedProfile),
           profiles.contains(where: { $0.id == id }) {
            selectedProfileID = id
        } else if selectedProfileID == nil {
            selectedProfileID = profiles.first?.id
        }

        if let record = preselectedLibraryApp {
            displayName = record.displayName
            bundleID = record.bundleIdentifier
            outputFilename = "\(record.displayName)-signed.ipa"
            await preparePackage(from: record)
        } else if selectedPackageID == nil {
            selectedPackageID = packages.first?.id
        }
    }

    private func preparePackage(from record: LibraryAppRecord) async {
        if let existing = packages.first(where: { $0.sourceURL.path == record.filePath }) {
            selectedPackageID = existing.id
            return
        }
        isPreparing = true
        defer { isPreparing = false }
        do {
            let workspace = try await environment.workspaceManager.createWorkspace()
            let importResult = try await environment.ipaImporter.importIPA(from: record.fileURL, workspace: workspace)
            let extractionDir = workspace.appendingPathComponent("extracted", isDirectory: true)
            _ = try await environment.ipaExtractor.extract(
                archiveURL: importResult.copiedFileURL,
                to: extractionDir,
                limits: .default
            )
            var package = try await environment.ipaInspector.inspect(extractedPayloadURL: extractionDir)
            package = AppPackage(
                id: record.id,
                sourceURL: record.fileURL,
                originalFilename: record.originalFilename,
                sha256: record.sha256.isEmpty ? importResult.sha256 : record.sha256,
                fileSize: record.byteSize == 0 ? importResult.fileSize : record.byteSize,
                applicationBundleURL: package.applicationBundleURL,
                displayName: record.displayName,
                executableName: package.executableName,
                primaryBundleIdentifier: record.bundleIdentifier,
                version: record.version,
                buildNumber: record.buildNumber,
                minimumOSVersion: record.minimumOSVersion.isEmpty ? package.minimumOSVersion : record.minimumOSVersion,
                architectures: package.architectures,
                nestedBundles: package.nestedBundles,
                embeddedProvisioningProfile: package.embeddedProvisioningProfile,
                requestedEntitlements: package.requestedEntitlements,
                inspectionWarnings: package.inspectionWarnings,
                existingSignatureStatus: package.existingSignatureStatus
            )
            try? await environment.workspaceManager.removeWorkspace(workspace)
            packages.insert(package, at: 0)
            environment.inspectedPackages = packages
            selectedPackageID = package.id
        } catch {
            errorMessage = (error as? SignFlowError)?.explanation ?? error.localizedDescription
        }
    }

    private func missingAsset(
        _ text: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(text, systemImage: "exclamationmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
                .tint(SignFlowTheme.accent)
        }
    }

    private func continueToPreflight() {
        guard let package = selectedPackage,
              let identity = selectedIdentity,
              let profile = selectedProfile else { return }

        UserDefaults.standard.set(identity.id.uuidString, forKey: SignFlowPreferences.selectedIdentityIDKey)
        UserDefaults.standard.set(profile.id.uuidString, forKey: SignFlowPreferences.selectedProfileIDKey)
        SignFlowPreferences.signingOptions = options

        let config = SigningConfiguration(
            package: package,
            identity: identity,
            profile: profile,
            requestedDisplayName: displayName.isEmpty ? nil : displayName,
            requestedPrimaryBundleIdentifier: bundleID.isEmpty ? nil : bundleID,
            entitlementStrategy: strategy,
            removeUnsupportedEntitlements: strategy != .strict,
            outputFilename: outputFilename.isEmpty
                ? "\(package.displayName)-signed.ipa"
                : outputFilename,
            options: options
        )
        router.navigate(to: .preflight(config))
    }
}
