import SwiftUI

struct CertificateDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    let identity: SigningIdentity
    @State private var matchingProfiles: [ProvisioningProfile] = []
    @State private var showDeleteConfirm = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        List {
            Section("Identity") {
                row("Common Name", identity.commonName)
                row("Issuer", identity.issuer)
                row("Type", identity.certificateType.rawValue.capitalized)
                row("Serial", identity.serialNumber)
                if let team = identity.teamIdentifier {
                    row("Team ID", team)
                }
                row("Private Key", identity.hasPrivateKey ? "Present" : "Missing")
            }

            Section("Validity") {
                row("Valid From", dateFormatter.string(from: identity.validFrom))
                row("Expires", dateFormatter.string(from: identity.expiresAt))
                row("Status", identity.isExpired ? "Expired" : "\(identity.daysRemaining) days remaining")
            }

            Section("Fingerprint") {
                Text(identity.fingerprintSHA256)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            if !matchingProfiles.isEmpty {
                Section("Matching Profiles") {
                    ForEach(matchingProfiles) { profile in
                        Button {
                            router.navigate(to: .profileDetail(profile))
                        } label: {
                            Text(profile.name)
                        }
                    }
                }
            } else {
                Section("Matching Profiles") {
                    Text("No imported profiles include this certificate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Delete Certificate", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle("Certificate")
        .task { await loadMatches() }
        .confirmationDialog("Delete this certificate?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await environment.certificateStore.deleteIdentity(id: identity.id)
                    await environment.refreshExpirationWarnings()
                    router.pop()
                }
            }
        } message: {
            Text("The identity will be removed from the Keychain. This cannot be undone.")
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
        let profiles = (try? await environment.profileStore.listProfiles()) ?? []
        matchingProfiles = CertificateProfileMatcher.matchingProfiles(profiles, for: identity)
    }
}
