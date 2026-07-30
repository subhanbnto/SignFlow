import SwiftUI

struct ProfileListView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var profiles: [ProvisioningProfile] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if profiles.isEmpty {
                ContentUnavailableView(
                    "No Profiles",
                    systemImage: "doc.badge.gearshape",
                    description: Text("Import a .mobileprovision file from your Apple Developer account.")
                )
            } else {
                ForEach(profiles) { profile in
                    Button {
                        router.navigate(to: .profileDetail(profile))
                    } label: {
                        ProfileRow(profile: profile)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Profiles")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SignFlowTheme.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: .importProfile)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func reload() async {
        profiles = (try? await environment.profileStore.listProfiles()) ?? []
    }

    private func delete(at offsets: IndexSet) {
        Task {
            for index in offsets {
                try? await environment.profileStore.deleteProfile(id: profiles[index].id)
            }
            await reload()
            await environment.refreshExpirationWarnings()
        }
    }
}

struct ProfileRow: View {
    let profile: ProvisioningProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(profile.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                if profile.isExpired {
                    SignFlowStatusBadge(text: "Expired", kind: .blocked)
                } else if profile.isExpiringSoon {
                    SignFlowStatusBadge(text: "\(profile.daysRemaining)d", kind: .warning)
                } else {
                    SignFlowStatusBadge(text: "Valid", kind: .ready)
                }
            }
            Text(profile.profileType.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let appID = profile.applicationIdentifier {
                Text(appID)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
