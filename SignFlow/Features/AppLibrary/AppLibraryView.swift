import SwiftUI
import UniformTypeIdentifiers

struct AppLibraryView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var searchText = ""
    @State private var scope: LibraryScope = .all
    @State private var editMode: EditMode = .inactive
    @State private var selectedIDs: Set<UUID> = []
    @State private var showImporter = false
    @State private var showURLImport = false
    @State private var urlString = ""
    @State private var errorMessage: String?
    @State private var infoRecord: LibraryAppRecord?
    @State private var installRecord: LibraryAppRecord?

    private var filtered: [LibraryAppRecord] {
        environment.libraryApps.filter { record in
            switch scope {
            case .all: break
            case .signed: if record.kind != .signed { return false }
            case .imported: if record.kind != .imported { return false }
            }
            if searchText.isEmpty { return true }
            return record.displayName.localizedCaseInsensitiveContains(searchText)
                || record.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var signed: [LibraryAppRecord] { filtered.filter { $0.kind == .signed } }
    private var imported: [LibraryAppRecord] { filtered.filter { $0.kind == .imported } }

    var body: some View {
        List(selection: $selectedIDs) {
            if !signed.isEmpty, scope == .all || scope == .signed {
                Section {
                    ForEach(signed) { record in
                        LibraryCellView(
                            record: record,
                            onInfo: { infoRecord = record },
                            onSign: { router.navigate(to: .signingSetupForLibrary(record)) },
                            onInstall: { installRecord = record }
                        )
                        .tag(record.id)
                    }
                } header: {
                    Text("Signed (\(signed.count))")
                }
            }

            if !imported.isEmpty, scope == .all || scope == .imported {
                Section {
                    ForEach(imported) { record in
                        LibraryCellView(
                            record: record,
                            onInfo: { infoRecord = record },
                            onSign: { router.navigate(to: .signingSetupForLibrary(record)) },
                            onInstall: { installRecord = record }
                        )
                        .tag(record.id)
                    }
                } header: {
                    Text("Imported (\(imported.count))")
                }
            }
        }
        .environment(\.editMode, $editMode)
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label("No Apps", systemImage: "questionmark.app.fill")
                } description: {
                    Text("Get started by importing your first IPA file.")
                } actions: {
                    Menu {
                        importActions
                    } label: {
                        Text("Import")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(SignFlowTheme.accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(SignFlowTheme.accent)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search")
        .searchScopes($scope) {
            ForEach(LibraryScope.allCases, id: \.self) { item in
                Text(item.displayName).tag(item)
            }
        }
        .navigationTitle("Library")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            if editMode.isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Delete", role: .destructive) {
                        Task { await deleteSelected() }
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        importActions
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data, UTType(filenameExtension: "tipa") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls {
                    router.navigate(to: .inspecting(url))
                }
            }
        }
        .alert("Import from URL", isPresented: $showURLImport) {
            TextField("URL", text: $urlString)
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) { urlString = "" }
            Button("OK") {
                Task { await importFromURL() }
            }
        }
        .sheet(item: $infoRecord) { record in
            LibraryAppInfoSheet(record: record)
        }
        .sheet(item: $installRecord) { record in
            LibraryInstallSheet(record: record)
                .presentationDetents([.height(220)])
        }
        .alert("Library", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await environment.refreshLibrary() }
        .refreshable { await environment.refreshLibrary() }
    }

    @ViewBuilder
    private var importActions: some View {
        Button("Import from Files", systemImage: "folder") { showImporter = true }
        Button("Import from URL", systemImage: "globe") { showURLImport = true }
    }

    private func deleteSelected() async {
        try? await environment.libraryStore.delete(ids: selectedIDs)
        selectedIDs.removeAll()
        await environment.refreshLibrary()
        editMode = .inactive
    }

    private func importFromURL() async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Enter a valid URL."
            return
        }
        do {
            let local = try await environment.downloadManager.startDownload(from: url)
            urlString = ""
            router.navigate(to: .inspecting(local))
        } catch {
            errorMessage = (error as? SignFlowError)?.explanation ?? error.localizedDescription
        }
    }
}

enum LibraryScope: String, CaseIterable {
    case all, signed, imported

    var displayName: String {
        switch self {
        case .all: return "All"
        case .signed: return "Signed"
        case .imported: return "Imported"
        }
    }
}

struct LibraryCellView: View {
    let record: LibraryAppRecord
    let onInfo: () -> Void
    let onSign: () -> Void
    let onInstall: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: record.kind == .signed ? "checkmark.seal.fill" : "app.fill")
                .font(.title2)
                .foregroundStyle(SignFlowTheme.accent)
                .frame(width: 48, height: 48)
                .background(SignFlowTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(record.displayName).font(.headline)
                Text(record.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("v\(record.version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Menu {
                Button("Get Info", systemImage: "info.circle", action: onInfo)
                Button("Sign", systemImage: "signature", action: onSign)
                if record.kind == .signed {
                    Button("Install", systemImage: "arrow.down.app", action: onInstall)
                }
                Button("Open Details", systemImage: "chevron.right") {
                    // Navigation handled by parent button if needed
                    onInfo()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(SignFlowTheme.accent)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSign)
        .contextMenu {
            Button("Get Info", action: onInfo)
            Button("Sign", action: onSign)
            if record.kind == .signed {
                Button("Install", action: onInstall)
            }
        }
    }
}

struct LibraryAppDetailView: View {
    let record: LibraryAppRecord
    @Environment(AppRouter.self) private var router

    var body: some View {
        List {
            Section("App") {
                LabeledContent("Name", value: record.displayName)
                LabeledContent("Bundle ID", value: record.bundleIdentifier)
                LabeledContent("Version", value: record.version)
                LabeledContent("Kind", value: record.kind.rawValue.capitalized)
                LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: Int64(record.byteSize), countStyle: .file))
            }
            Section {
                Button {
                    router.navigate(to: .signingSetupForLibrary(record))
                } label: {
                    Label("Sign", systemImage: "signature")
                }
            }
        }
        .navigationTitle(record.displayName)
    }
}

struct LibraryAppInfoSheet: View {
    let record: LibraryAppRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Name", value: record.displayName)
                LabeledContent("Identifier", value: record.bundleIdentifier)
                LabeledContent("Version", value: record.version)
                LabeledContent("Build", value: record.buildNumber)
                LabeledContent("SHA-256", value: record.sha256)
                LabeledContent("File", value: record.originalFilename)
                if let source = record.sourceName {
                    LabeledContent("Source", value: source)
                }
            }
            .navigationTitle("App Info")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct LibraryInstallSheet: View {
    let record: LibraryAppRecord
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var message = "Preparing installation…"
    @State private var isWorking = true

    var body: some View {
        VStack(spacing: 16) {
            Text(record.displayName).font(.headline)
            if isWorking { ProgressView() }
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
        }
        .padding(24)
        .task { await install() }
    }

    private func install() async {
        let request = InstallationRequest(
            ipaURL: record.fileURL,
            outputSHA256: record.sha256,
            bundleIdentifier: record.bundleIdentifier,
            bundleVersion: record.version,
            displayName: record.displayName,
            profileType: ProfileType(rawValue: record.profileTypeRaw ?? "") ?? .development,
            profileName: record.profileTypeRaw ?? "Signed",
            outputFilename: record.originalFilename,
            byteSize: record.byteSize
        )
        do {
            let result = try await environment.appInstaller.install(request: request) { progress in
                Task { @MainActor in message = progress.message }
            }
            await MainActor.run {
                message = result.message
                isWorking = false
            }
        } catch {
            await MainActor.run {
                message = (error as? SignFlowError)?.explanation ?? error.localizedDescription
                isWorking = false
            }
        }
    }
}
