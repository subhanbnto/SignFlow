import SwiftUI
import UniformTypeIdentifiers

struct ImportProfileView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var error: SignFlowError?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.badge.gearshape")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Import Provisioning Profile")
                .font(.title2.bold())

            Text("Select a .mobileprovision file from your Apple Developer account. Compatibility with an app is verified later during preflight.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showFilePicker = true
            } label: {
                if isImporting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Browse Files", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .disabled(isImporting)

            Spacer()
        }
        .navigationTitle("Import Profile")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "mobileprovision") ?? .data,
                UTType(filenameExtension: "provisionprofile") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await importProfile(url) }
            case .failure:
                error = .malformedProvisioningProfile(detail: "Could not open the selected file.")
                showError = true
            }
        }
        .alert("Import Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let error {
                Text("\(error.explanation)\n\n\(error.suggestedResolution)")
            }
        }
    }

    private func importProfile(_ url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let profile = try await environment.profileImporter.importProfile(from: url)
            await environment.refreshExpirationWarnings()
            router.pop()
            router.navigate(to: .profileDetail(profile))
        } catch let sfError as SignFlowError {
            error = sfError
            showError = true
        } catch {
            self.error = .malformedProvisioningProfile(detail: error.localizedDescription)
            showError = true
        }
    }
}
