import SwiftUI

struct SigningAssetsView: View {
    @AppStorage("developerAccountPlan") private var planRaw = DeveloperAccountPlan.free.rawValue
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var identities: [SigningIdentity] = []
    @State private var profiles: [ProvisioningProfile] = []

    private var plan: DeveloperAccountPlan {
        DeveloperAccountPlan(rawValue: planRaw) ?? .free
    }

    private var isReady: Bool {
        identities.contains { !$0.isExpired && $0.hasPrivateKey }
            && profiles.contains { !$0.isExpired }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                SignFlowPanel {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: isReady ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                            .font(.title2)
                            .foregroundStyle(isReady ? .green : SignFlowTheme.accent)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(isReady ? "Ready to sign" : "Setup required")
                                    .font(.headline)
                                Spacer()
                                SignFlowStatusBadge(
                                    text: plan == .free ? "Free · 7 days" : "Developer Program",
                                    kind: plan == .free ? .warning : .ready
                                )
                            }
                            Text(isReady
                                 ? "A valid identity and profile are stored locally."
                                 : "Add one signing identity and one matching profile.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                setupGuidance

                assetButton(
                    icon: "person.badge.key",
                    title: "Certificates",
                    detail: "\(identities.count) imported",
                    ready: identities.contains { !$0.isExpired },
                    action: { router.navigate(to: .certificates) }
                )

                assetButton(
                    icon: "doc.badge.gearshape",
                    title: "Provisioning Profiles",
                    detail: "\(profiles.count) imported",
                    ready: profiles.contains { !$0.isExpired },
                    action: { router.navigate(to: .profiles) }
                )
            }
            .padding(20)
        }
        .background(SignFlowTheme.background)
        .navigationTitle("Signing Assets")
        .task { await reload() }
        .refreshable { await reload() }
    }

    private var setupGuidance: some View {
        SignFlowPanel {
            VStack(alignment: .leading, spacing: 14) {
                SignFlowSectionHeader(
                    title: plan == .free ? "Free account setup" : "Developer account setup",
                    subtitle: plan == .free
                        ? "Xcode creates temporary assets for your Apple ID."
                        : "Use assets from Certificates, IDs & Profiles."
                )

                if plan == .free {
                    setupStep(1, "Connect your iPhone to Xcode and enable automatic signing.")
                    setupStep(2, "Run any personal-team app once so Xcode creates a certificate and profile.")
                    setupStep(3, "Export the certificate with its private key as P12 from Keychain Access.")
                    setupStep(4, "Import the Xcode-managed profile. Free profiles normally expire after 7 days.")
                } else {
                    setupStep(1, "Create an Apple Development certificate in the Developer Portal or Xcode.")
                    setupStep(2, "Create a Development or Ad Hoc profile for your App ID and devices.")
                    setupStep(3, "Export the certificate and private key as P12, then import both assets below.")
                }

                Text("SignFlow never requests your Apple ID password and cannot silently create Apple assets on iOS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func setupStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(SignFlowTheme.accent, in: Circle())
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func assetButton(
        icon: String,
        title: String,
        detail: String,
        ready: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(SignFlowTheme.accent)
                    .frame(width: 48, height: 48)
                    .background(SignFlowTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SignFlowStatusBadge(text: ready ? "Ready" : "Add", kind: ready ? .ready : .neutral)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(SignFlowTheme.surface, in: RoundedRectangle(cornerRadius: SignFlowTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    private func reload() async {
        identities = (try? await environment.certificateStore.listIdentities()) ?? []
        profiles = (try? await environment.profileStore.listProfiles()) ?? []
    }
}
