import SwiftUI

struct ProfileDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    let profile: ProvisioningProfile
    @State private var matchingIdentities: [SigningIdentity] = []
    @State private var showDeleteConfirm = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        List {
            Section("Profile") {
                row("Name", profile.name)
                row("UUID", profile.uuid)
                row("Type", profile.profileType.rawValue)
                if let team = profile.teamIdentifier {
                    row("Team ID", team)
                }
                if let appID = profile.applicationIdentifier {
                    row("App ID", appID)
                }
                if let appIDName = profile.appIDName {
                    row("App ID Name", appIDName)
                }
                row("Platforms", profile.supportedPlatforms.joined(separator: ", "))
            }

            Section("Validity") {
                row("Created", dateFormatter.string(from: profile.creationDate))
                row("Expires", dateFormatter.string(from: profile.expirationDate))
                row("Status", profile.isExpired ? "Expired" : "\(profile.daysRemaining) days remaining")
            }

            Section("Devices") {
                if profile.provisionsAllDevices {
                    Text("Provisions all devices (Enterprise)")
                } else if let devices = profile.provisionedDevices {
                    row("Registered Devices", "\(devices.count)")
                } else {
                    Text("No device list (likely App Store profile)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Certificates in Profile (\(profile.developerCertificateFingerprints.count))") {
                ForEach(profile.developerCertificateFingerprints, id: \.self) { fingerprint in
                    Text(fingerprint)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            if !matchingIdentities.isEmpty {
                Section("Matching Imported Identities") {
                    ForEach(matchingIdentities) { identity in
                        Button {
                            router.navigate(to: .certificateDetail(identity))
                        } label: {
                            Text(identity.displayName)
                        }
                    }
                }
            } else {
                Section("Matching Imported Identities") {
                    Text("No imported certificates match this profile. Compatibility with an IPA is determined during preflight (Milestone 3).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Entitlements (\(profile.entitlements.count))") {
                ForEach(profile.entitlements.keys.sorted(), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(key)
                            .font(.caption.bold())
                        Text(profile.entitlements[key] ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button("Delete Profile", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle("Profile")
        .task { await loadMatches() }
        .confirmationDialog("Delete this profile?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await environment.profileStore.deleteProfile(id: profile.id)
                    await environment.refreshExpirationWarnings()
                    router.pop()
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func loadMatches() async {
        let identities = (try? await environment.certificateStore.listIdentities()) ?? []
        matchingIdentities = CertificateProfileMatcher.matchingIdentities(identities, in: profile)
    }
}
