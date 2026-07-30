import SwiftUI

struct DashboardView: View {
    @AppStorage("developerAccountPlan") private var planRaw = DeveloperAccountPlan.free.rawValue
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var identities: [SigningIdentity] = []
    @State private var profiles: [ProvisioningProfile] = []

    private var expirationWarnings: [String] {
        var warnings: [String] = []
        for identity in identities where identity.isExpired || identity.isExpiringSoon {
            if identity.isExpired {
                warnings.append("Certificate \"\(identity.displayName)\" has expired.")
            } else {
                warnings.append("Certificate \"\(identity.displayName)\" expires in \(identity.daysRemaining) days.")
            }
        }
        for profile in profiles where profile.isExpired || profile.isExpiringSoon {
            if profile.isExpired {
                warnings.append("Profile \"\(profile.name)\" has expired.")
            } else {
                warnings.append("Profile \"\(profile.name)\" expires in \(profile.daysRemaining) days.")
            }
        }
        return warnings
    }

    private var isReady: Bool {
        identities.contains { !$0.isExpired && $0.hasPrivateKey }
            && profiles.contains { !$0.isExpired }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero

                if !isReady {
                    setupStatus
                }

                if !expirationWarnings.isEmpty {
                    expirationStatus
                }

                SignFlowSectionHeader(
                    title: "Your workspace",
                    subtitle: "Recently imported apps and signing status."
                )

                if environment.inspectedPackages.isEmpty {
                    SignFlowPanel {
                        SignFlowEmptyState(
                            systemImage: "shippingbox",
                            title: "No apps yet",
                            message: "Import your first IPA to inspect and prepare it for signing.",
                            actionTitle: "Import IPA"
                        ) {
                            router.navigate(to: .importIPA)
                        }
                    }
                } else {
                    ForEach(environment.inspectedPackages.prefix(3)) { package in
                        appRow(package)
                    }
                }
            }
            .padding(20)
        }
        .background(SignFlowTheme.background)
        .navigationTitle("SignFlow")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reloadAssets() }
        .refreshable { await reloadAssets() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SIGNFLOW")
                        .font(.caption.weight(.bold))
                        .tracking(2.2)
                        .foregroundStyle(.white.opacity(0.75))
                    Text("Sign with\nconfidence.")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .tracking(-1)
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "signature")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 18))
            }

            Text(isReady
                 ? "Your signing assets are ready. Import an IPA or continue with an app in your library."
                 : "Complete signing setup once, then sign imported IPAs in a guided flow.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 10) {
                Button {
                    router.navigate(to: .signingSetup)
                } label: {
                    Label("Sign an App", systemImage: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(SignFlowTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)

                Button {
                    router.navigate(to: .importIPA)
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [SignFlowTheme.accent, SignFlowTheme.accent.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28)
        )
    }

    private var setupStatus: some View {
        SignFlowPanel {
            HStack(spacing: 14) {
                Image(systemName: "key.horizontal")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 46, height: 46)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Finish signing setup")
                        .font(.headline)
                    Text("\(identities.count)/1 certificate · \(profiles.count)/1 profile")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                SignFlowStatusBadge(
                    text: planRaw == DeveloperAccountPlan.free.rawValue ? "Free account" : "Paid account",
                    kind: .warning
                )
            }
        }
        .onTapGesture {
            if identities.isEmpty {
                router.navigate(to: .importCertificate)
            } else if profiles.isEmpty {
                router.navigate(to: .importProfile)
            }
        }
    }

    private var expirationStatus: some View {
        SignFlowPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label("Expiration attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                ForEach(expirationWarnings.prefix(2), id: \.self) { warning in
                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func appRow(_ package: AppPackage) -> some View {
        Button {
            router.navigate(to: .appDetails(package))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "app.dashed")
                    .font(.title3)
                    .foregroundStyle(SignFlowTheme.accent)
                    .frame(width: 50, height: 50)
                    .background(SignFlowTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 3) {
                    Text(package.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(package.primaryBundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(package.version)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(SignFlowTheme.surface, in: RoundedRectangle(cornerRadius: SignFlowTheme.cornerRadius))
        }
        .buttonStyle(.plain)
    }

    private func reloadAssets() async {
        identities = (try? await environment.certificateStore.listIdentities()) ?? []
        profiles = (try? await environment.profileStore.listProfiles()) ?? []
    }
}
