import SwiftUI
import UIKit

struct AppearanceSettingsView: View {
    @AppStorage(SignFlowPreferences.appearanceStyleKey) private var style = AppearanceStyleSetting.system.rawValue
    @AppStorage(SignFlowPreferences.storeCellAppearanceKey) private var storeCell = 0

    var body: some View {
        List {
            Section {
                Picker("Appearance", selection: $style) {
                    ForEach(AppearanceStyleSetting.allCases, id: \.rawValue) { item in
                        Text(item.displayName).tag(item.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                LabeledContent("Accent", value: "Orange")
                Text("SignFlow uses orange as the primary accent across Sources, Library, and Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Theme")
            }

            Section {
                Picker("Store Cell Appearance", selection: $storeCell) {
                    Text("Standard").tag(0)
                    Text("Big Description").tag(1)
                }
                .pickerStyle(.inline)
            } header: {
                Text("Sources")
            } footer: {
                Text("Standard shows subtitle only. Big Description also includes the localized app description.")
            }
        }
        .navigationTitle("Appearance")
    }
}

struct SigningOptionsSettingsView: View {
    @State private var options = SignFlowPreferences.signingOptions
    @State private var showPPQEditor = false
    @State private var ppqDraft = ""

    var body: some View {
        List {
            Section {
                NavigationLink("Display Names") {
                    DictionaryRulesView(title: "Display Names", rules: $options.displayNameRules)
                }
                NavigationLink("Identifiers") {
                    DictionaryRulesView(title: "Identifiers", rules: $options.identifierRules)
                }
            } footer: {
                Text("Automatically replace display names or bundle identifiers when signing.")
            }

            SigningOptionsForm(options: $options)

            Section("PPQ String") {
                LabeledContent("Current", value: options.ppqString)
                Button("Change") {
                    ppqDraft = options.ppqString
                    showPPQEditor = true
                }
                Button("Copy") {
                    UIPasteboard.general.string = options.ppqString
                }
            }
        }
        .navigationTitle("Signing Options")
        .onChange(of: options) { _, newValue in
            SignFlowPreferences.signingOptions = newValue
        }
        .alert("PPQ String", isPresented: $showPPQEditor) {
            TextField("String", text: $ppqDraft)
            Button("Save") {
                if !ppqDraft.isEmpty { options.ppqString = ppqDraft }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

struct SigningOptionsForm: View {
    @Binding var options: SigningOptions

    var body: some View {
        Section {
            Toggle(isOn: $options.ppqProtection) {
                Label("PPQ Protection", systemImage: "shield")
            }
        } header: {
            Text("Protection")
        } footer: {
            Text("Appends a random string to bundle identifiers to reduce Apple ID flagging risk.")
        }

        Section("General") {
            Picker(selection: $options.appAppearance) {
                ForEach(SigningAppearanceMode.allCases, id: \.self) { Text($0.displayName).tag($0) }
            } label: {
                Label("Appearance", systemImage: "paintpalette")
            }
            Picker(selection: $options.minimumAppRequirement) {
                ForEach(MinimumAppRequirement.allCases, id: \.self) { Text($0.displayName).tag($0) }
            } label: {
                Label("Minimum Requirement", systemImage: "ruler")
            }
        }

        Section("App Features") {
            toggle("File Sharing", "folder.badge.person.crop", $options.fileSharing)
            toggle("iTunes File Sharing", "music.note.list", $options.itunesFileSharing)
            toggle("Pro Motion", "speedometer", $options.proMotion)
            toggle("Game Mode", "gamecontroller", $options.gameMode)
            toggle("iPad Fullscreen", "ipad.landscape", $options.ipadFullscreen)
        }

        Section {
            toggle("Remove URL Scheme", "ellipsis.curlybraces", $options.removeURLScheme)
            toggle("Remove Provisioning", "doc.badge.gearshape", $options.removeProvisioning)
        } header: {
            Text("Removal")
        } footer: {
            Text("Removing the provisioning file excludes embedded.mobileprovision from the signed app.")
        }

        Section {
            toggle("Force Localize", "character.bubble", $options.forceLocalizeDisplayName)
        } footer: {
            Text("Overrides localized display names inside InfoPlist.strings.")
        }

        Section("Post Signing") {
            toggle("Install After Signing", "arrow.down.circle", $options.installAfterSigning)
            toggle("Delete After Signing", "trash", $options.deleteImportedAfterSigning)
        }

        Section {
            Toggle(isOn: $options.disableLiquidGlass) {
                Label("Disable Liquid Glass", systemImage: "18.circle")
            }
            .disabled(options.enableLiquidGlass)
            Toggle(isOn: $options.enableLiquidGlass) {
                Label("Enable Liquid Glass", systemImage: "26.circle")
            }
            .disabled(options.disableLiquidGlass)
            toggle("Inject into Extensions", "syringe", $options.injectIntoExtensions)
        } header: {
            Text("Experiments")
        } footer: {
            Text("Liquid Glass toggles patch Info.plist compatibility flags. Tweak load-command rewriting remains experimental.")
        }
    }

    private func toggle(_ title: String, _ image: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Label(title, systemImage: image)
        }
    }
}

struct DictionaryRulesView: View {
    let title: String
    @Binding var rules: [String: String]
    @State private var key = ""
    @State private var value = ""

    var body: some View {
        List {
            Section {
                ForEach(rules.keys.sorted(), id: \.self) { item in
                    LabeledContent(item, value: rules[item] ?? "")
                }
                .onDelete { indexSet in
                    let keys = rules.keys.sorted()
                    for index in indexSet {
                        rules.removeValue(forKey: keys[index])
                    }
                }
            }

            Section("Add Rule") {
                TextField("Original", text: $key)
                    .textInputAutocapitalization(.never)
                TextField("Replacement", text: $value)
                    .textInputAutocapitalization(.never)
                Button("Add") {
                    let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedKey.isEmpty, !trimmedValue.isEmpty else { return }
                    rules[trimmedKey] = trimmedValue
                    key = ""
                    value = ""
                }
            }
        }
        .navigationTitle(title)
    }
}

struct ArchiveSettingsView: View {
    @AppStorage(SignFlowPreferences.compressionLevelKey) private var compression = CompressionLevelSetting.defaultLevel.rawValue
    @AppStorage(SignFlowPreferences.showShareSheetKey) private var showShare = false

    var body: some View {
        List {
            Section {
                Picker(selection: $compression) {
                    ForEach(CompressionLevelSetting.allCases, id: \.rawValue) { level in
                        Text(level.displayName).tag(level.rawValue)
                    }
                } label: {
                    Label("Compression Level", systemImage: "archivebox")
                }
            }

            Section {
                Toggle(isOn: $showShare) {
                    Label("Show Sheet when Exporting", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Present a share sheet after exporting a signed IPA.")
            }
        }
        .navigationTitle("Archive & Compression")
    }
}

struct InstallationSettingsView: View {
    @AppStorage(SignFlowPreferences.installationMethodKey) private var method = InstallationMethodSetting.server.rawValue
    @AppStorage(InstallerSettings.endpointURLKey) private var installerURL = InstallerSettings.defaultEndpointURLString
    @AppStorage(InstallerSettings.retentionDisclosureAcknowledgedKey) private var retentionAcknowledged = false
    @Environment(AppEnvironment.self) private var environment

    @State private var apiToken = ""
    @State private var hasStoredToken = false
    @State private var isTesting = false
    @State private var connectionMessage: String?
    @State private var connectionIsError = false
    @State private var showIDeviceWarning = false

    var body: some View {
        List {
            Section {
                Picker(selection: $method) {
                    ForEach(InstallationMethodSetting.allCases, id: \.rawValue) { item in
                        Text(item.displayName).tag(item.rawValue)
                    }
                } label: {
                    Label("Installation Type", systemImage: "arrow.down.app")
                }
            } footer: {
                Text("Server (Recommended): HTTPS OTA through your private Cloudflare installer.\n\nidevice (Advanced): pairing-file installation is experimental and not fully available in this build.")
            }

            if method == InstallationMethodSetting.server.rawValue {
                Section {
                    TextField("https://signflow-installer.<account>.workers.dev", text: $installerURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    SecureField(hasStoredToken ? "API token (saved)" : "API token", text: $apiToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle("Allow temporary IPA uploads for OTA", isOn: $retentionAcknowledged)
                    Button {
                        Task { await save() }
                    } label: {
                        Label("Save Installer Settings", systemImage: "key.fill")
                    }
                    Button {
                        Task { await test() }
                    } label: {
                        if isTesting { ProgressView() } else {
                            Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                    .disabled(isTesting)
                    if let connectionMessage {
                        Text(connectionMessage)
                            .font(.caption)
                            .foregroundStyle(connectionIsError ? .red : .secondary)
                    }
                } header: {
                    Text("Server")
                }
            } else {
                Section {
                    Text("idevice installation requires a pairing file and a maintainable device communication stack. This build keeps the option visible for parity and routes installs through Server/share until pairing support ships.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Tunnel & Pairing")
                }
            }
        }
        .navigationTitle("Installation")
        .onChange(of: method) { _, newValue in
            if newValue == InstallationMethodSetting.idevice.rawValue {
                showIDeviceWarning = true
            }
        }
        .alert("Advanced Installation Method", isPresented: $showIDeviceWarning) {
            Button("Switch Back", role: .destructive) {
                method = InstallationMethodSetting.server.rawValue
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("idevice support is experimental. Prefer Server OTA for reliable installs.")
        }
        .task {
            hasStoredToken = (try? await InstallerAPITokenStore().hasToken()) == true
        }
    }

    private func save() async {
        do {
            if !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try await InstallerAPITokenStore().save(token: apiToken)
                apiToken = ""
                hasStoredToken = true
            }
            InstallerSettings.endpointURLString = installerURL
            InstallerSettings.retentionAcknowledged = retentionAcknowledged
            connectionMessage = "Installer settings saved."
            connectionIsError = false
        } catch {
            connectionMessage = (error as? SignFlowError)?.explanation ?? error.localizedDescription
            connectionIsError = true
        }
    }

    private func test() async {
        isTesting = true
        defer { isTesting = false }
        do {
            if !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                try await InstallerAPITokenStore().save(token: apiToken)
                apiToken = ""
                hasStoredToken = true
            }
            InstallerSettings.endpointURLString = installerURL
            connectionMessage = try await environment.appInstaller.testConnection()
            connectionIsError = false
        } catch {
            connectionMessage = (error as? SignFlowError)?.explanation ?? error.localizedDescription
            connectionIsError = true
        }
    }
}

struct AboutSignFlowView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: "0.1.0")
                LabeledContent("Signing Engine", value: "zsign / Zupersign")
                LabeledContent("Archive", value: "ZIPFoundation")
            }
            Section("Privacy") {
                Text("Signing credentials and IPA files are processed locally. Optional OTA installation uploads only the signed IPA to your configured private backend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Authorized Use") {
                Text("Use SignFlow only with applications, certificates, profiles, accounts, and devices you own or are authorized to use.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About SignFlow")
    }
}

struct ResetSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var message: String?

    var body: some View {
        List {
            Section {
                Button("Reset Sources", role: .destructive) {
                    Task {
                        try? await environment.sourceStore.clearAll()
                        await environment.refreshSources()
                        message = "Sources cleared."
                    }
                }
                Button("Reset Library", role: .destructive) {
                    Task {
                        try? await environment.libraryStore.clearAll(deleteFiles: false)
                        await environment.refreshLibrary()
                        message = "Library index cleared. IPA files on disk were kept."
                    }
                }
                Button("Reset Library and Delete Files", role: .destructive) {
                    Task {
                        try? await environment.libraryStore.clearAll(deleteFiles: true)
                        await environment.refreshLibrary()
                        message = "Library and IPA files deleted."
                    }
                }
                Button("Clean Workspaces", role: .destructive) {
                    Task {
                        await environment.cleanupOrphanedWorkspaces()
                        message = "Temporary workspaces cleaned."
                    }
                }
            } footer: {
                Text("Certificates in Keychain are not deleted here. Remove them from the Certificates screen if needed.")
            }

            if let message {
                Section {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Reset")
    }
}
