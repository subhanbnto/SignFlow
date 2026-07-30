import SwiftUI
import UniformTypeIdentifiers

struct ImportCertificateView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var showFilePicker = false
    @State private var selectedURL: URL?
    @State private var password = ""
    @State private var isImporting = false
    @State private var error: SignFlowError?
    @State private var showError = false
    @State private var acknowledged = false

    var body: some View {
        Form {
            Section {
                Text("Only import certificates that you own or are authorized to use. Credentials stay on this device and are never uploaded.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Authorization") {
                Toggle("I confirm this certificate belongs to me or my organization", isOn: $acknowledged)
            }

            Section("P12 File") {
                Button {
                    showFilePicker = true
                } label: {
                    Label(
                        selectedURL?.lastPathComponent ?? "Choose P12 File",
                        systemImage: "doc.badge.plus"
                    )
                }
            }

            if selectedURL != nil {
                Section("Password") {
                    SecureField("P12 Password", text: $password)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    Text("The password is used once for import and is never saved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    Task { await importCertificate() }
                } label: {
                    if isImporting {
                        ProgressView()
                    } else {
                        Text("Import Certificate")
                    }
                }
                .disabled(!canImport || isImporting)
            }
        }
        .navigationTitle("Import Certificate")
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                UTType(filenameExtension: "p12") ?? .data,
                UTType(filenameExtension: "pfx") ?? .data
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedURL = urls.first
            case .failure:
                error = .invalidP12(detail: "Could not open the selected file.")
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

    private var canImport: Bool {
        acknowledged && selectedURL != nil && !password.isEmpty
    }

    private func importCertificate() async {
        guard let url = selectedURL else { return }
        isImporting = true
        defer {
            isImporting = false
            password = ""
        }

        do {
            let identity = try await environment.certificateImporter.importP12(from: url, password: password)
            await environment.refreshExpirationWarnings()
            router.pop()
            router.navigate(to: .certificateDetail(identity))
        } catch let sfError as SignFlowError {
            error = sfError
            showError = true
        } catch {
            self.error = .invalidP12(detail: error.localizedDescription)
            showError = true
        }
    }
}
