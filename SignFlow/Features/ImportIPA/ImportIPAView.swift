import SwiftUI
import UniformTypeIdentifiers

struct ImportIPAView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router
    @State private var showFilePicker = false
    @State private var importError: SignFlowError?
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 18) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(SignFlowTheme.accent)
                        .frame(width: 78, height: 78)
                        .background(SignFlowTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 24))

                    VStack(spacing: 7) {
                        Text("Import an IPA")
                            .font(.title2.weight(.bold))
                        Text("SignFlow copies the file into a protected workspace, checks its hash, and safely inspects the package.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 28)

                SignFlowPanel {
                    VStack(alignment: .leading, spacing: 15) {
                        infoRow("checkmark.shield", "Archive safety checks")
                        infoRow("number", "SHA-256 fingerprint")
                        infoRow("square.stack.3d.down.right", "Extensions and frameworks inventory")
                        infoRow("lock", "Local-only processing")
                    }
                }

                SignFlowPrimaryButton(title: "Choose IPA File", systemImage: "folder") {
                    showFilePicker = true
                }

                Text("Only import applications you own or are authorized to sign.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(SignFlowTheme.background)
        .navigationTitle("Import IPA")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "ipa") ?? .archive,
                .zip
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                router.navigate(to: .inspecting(url))
            case .failure(let error):
                importError = .invalidIPA(detail: error.localizedDescription)
                showError = true
            }
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            if let err = importError {
                Text(err.explanation)
            }
        }
    }

    private func infoRow(_ icon: String, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(SignFlowTheme.accent)
                .frame(width: 24)
        }
    }
}
