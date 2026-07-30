import SwiftUI

struct CertificateListView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var identities: [SigningIdentity] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            if identities.isEmpty {
                ContentUnavailableView(
                    "No Certificates",
                    systemImage: "person.badge.key",
                    description: Text("Import a P12 signing certificate that you own.")
                )
            } else {
                ForEach(identities) { identity in
                    Button {
                        router.navigate(to: .certificateDetail(identity))
                    } label: {
                        CertificateRow(identity: identity)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Certificates")
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SignFlowTheme.background)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: .importCertificate)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func reload() async {
        do {
            identities = try await environment.certificateStore.listIdentities()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let identity = identities[index]
                do {
                    try await environment.certificateStore.deleteIdentity(id: identity.id)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            await reload()
            await environment.refreshExpirationWarnings()
        }
    }
}

struct CertificateRow: View {
    let identity: SigningIdentity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(identity.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                statusBadge
            }
            Text(identity.certificateType.rawValue.capitalized)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let team = identity.teamIdentifier {
                Text("Team: \(team)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if identity.isExpired {
            SignFlowStatusBadge(text: "Expired", kind: .blocked)
        } else if identity.isExpiringSoon {
            SignFlowStatusBadge(text: "\(identity.daysRemaining)d", kind: .warning)
        } else {
            SignFlowStatusBadge(text: "Valid", kind: .ready)
        }
    }
}
