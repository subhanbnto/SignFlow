import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("developerAccountPlan") private var planRaw = DeveloperAccountPlan.free.rawValue
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var identities: [SigningIdentity] = []
    @State private var selectedIdentity: SigningIdentity?

    private var planBinding: Binding<DeveloperAccountPlan> {
        Binding(
            get: { DeveloperAccountPlan(rawValue: planRaw) ?? .free },
            set: { planRaw = $0.rawValue }
        )
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AboutSignFlowView()
                } label: {
                    Label {
                        Text("About SignFlow")
                    } icon: {
                        Image(systemName: "signature")
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(SignFlowTheme.accent.gradient, in: RoundedRectangle(cornerRadius: 7))
                    }
                }

                Link(destination: URL(string: "https://github.com")!) {
                    SignFlowTintedLabel(title: "Submit Feedback", systemImage: "safari")
                }
            } footer: {
                Text("If any issues occur within the app, report them with device details and the signing configuration you used.")
            }

            Section {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    SignFlowTintedLabel(title: "Appearance", systemImage: "paintbrush")
                }
            }

            Section {
                if let selectedIdentity {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedIdentity.displayName).font(.headline)
                        Text(selectedIdentity.teamIdentifier ?? "No team ID")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No Certificate")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                NavigationLink {
                    CertificateListView()
                } label: {
                    SignFlowTintedLabel(title: "Certificates", systemImage: "checkmark.seal")
                }

                NavigationLink {
                    ProfileListView()
                } label: {
                    SignFlowTintedLabel(title: "Provisioning Profiles", systemImage: "doc.badge.gearshape")
                }
            } header: {
                Text("Certificates")
            } footer: {
                Text("Add and manage certificates and profiles used for signing applications.")
            }

            Section {
                NavigationLink {
                    SigningOptionsSettingsView()
                } label: {
                    SignFlowTintedLabel(title: "Signing Options", systemImage: "signature")
                }
                NavigationLink {
                    ArchiveSettingsView()
                } label: {
                    SignFlowTintedLabel(title: "Archive & Compression", systemImage: "archivebox")
                }
                NavigationLink {
                    InstallationSettingsView()
                } label: {
                    SignFlowTintedLabel(title: "Installation", systemImage: "arrow.down.circle")
                }
            } header: {
                Text("Features")
            } footer: {
                Text("Configure installation, zip compression levels, and custom modifications to apps.")
            }

            Section {
                Picker("Account Type", selection: planBinding) {
                    ForEach(DeveloperAccountPlan.allCases, id: \.self) { plan in
                        Text(plan.title).tag(plan)
                    }
                }
            } header: {
                Text("Developer Account")
            }

            Section {
                Button {
                    openDocuments("Documents")
                } label: {
                    SignFlowTintedLabel(title: "Open Documents", systemImage: "folder")
                }
                Button {
                    openDocuments("Exports")
                } label: {
                    SignFlowTintedLabel(title: "Open Archives", systemImage: "folder")
                }
                Button {
                    openDocuments("Imports")
                } label: {
                    SignFlowTintedLabel(title: "Open Certificates Folder", systemImage: "folder")
                }
            } header: {
                Text("Misc")
            } footer: {
                Text("All of the app’s files are contained in the documents directory. These are quick links into Files.")
            }

            Section {
                NavigationLink {
                    ResetSettingsView()
                } label: {
                    Label("Reset", systemImage: "trash")
                }
            } footer: {
                Text("Reset sources, library apps, and temporary workspaces.")
            }

            Section {
                Button("Show Setup Assistant Again") {
                    hasCompletedOnboarding = false
                }
            }
        }
        .navigationTitle("Settings")
        .task { await reloadCertificates() }
    }

    private func reloadCertificates() async {
        identities = (try? await environment.certificateStore.listIdentities()) ?? []
        if let stored = UserDefaults.standard.string(forKey: SignFlowPreferences.selectedIdentityIDKey),
           let id = UUID(uuidString: stored) {
            selectedIdentity = identities.first { $0.id == id }
        } else {
            selectedIdentity = identities.first
        }
    }

    private func openDocuments(_ folder: String) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = folder == "Documents" ? docs : docs.appendingPathComponent(folder)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        // Prefer shared documents URL when available.
        if let shared = URL(string: "shareddocuments://\(url.path)") {
            UIApplication.shared.open(shared)
        }
    }
}
