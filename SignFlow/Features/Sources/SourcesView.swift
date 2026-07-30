import SwiftUI

struct SourcesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var searchText = ""
    @State private var showAddSource = false
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    private var filteredSources: [AppSource] {
        if searchText.isEmpty { return environment.sources }
        return environment.sources.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.url.absoluteString.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if !filteredSources.isEmpty {
                Section {
                    NavigationLink {
                        SourceAppsView(sources: environment.sources)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(SignFlowTheme.accent.gradient, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("All Repositories")
                                    .font(.headline)
                                Text("See all apps from your sources")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    ForEach(filteredSources) { source in
                        NavigationLink {
                            SourceAppsView(sources: [source])
                        } label: {
                            SourcesCellView(source: source)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await delete(source) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Repositories (\(filteredSources.count))")
                } footer: {
                    Text("Only add repositories you trust. SignFlow does not ship catalogs and never uploads your certificates.")
                }
            }
        }
        .overlay {
            if filteredSources.isEmpty {
                ContentUnavailableView {
                    Label("No Repositories", systemImage: "globe.desk.fill")
                } description: {
                    Text("Get started by adding your first repository.")
                } actions: {
                    Button("Add Source") { showAddSource = true }
                        .buttonStyle(.bordered)
                        .tint(SignFlowTheme.accent)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search")
        .navigationTitle("Sources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSource = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .refreshable { await refreshCatalogs() }
        .sheet(isPresented: $showAddSource) {
            SourcesAddView { source in
                Task { await add(source) }
            }
        }
        .alert("Sources", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task { await environment.refreshSources() }
    }

    private func add(_ source: AppSource) async {
        do {
            let catalog = try await environment.sourceFetcher.fetchCatalog(for: source)
            try await environment.sourceStore.addSource(catalog.source)
            await environment.refreshSources()
            showAddSource = false
        } catch {
            errorMessage = (error as? SignFlowError)?.explanation ?? error.localizedDescription
        }
    }

    private func delete(_ source: AppSource) async {
        try? await environment.sourceStore.deleteSource(id: source.id)
        await environment.refreshSources()
    }

    private func refreshCatalogs() async {
        isRefreshing = true
        defer { isRefreshing = false }
        for source in environment.sources {
            if let catalog = try? await environment.sourceFetcher.fetchCatalog(for: source) {
                try? await environment.sourceStore.updateSource(catalog.source)
            }
        }
        await environment.refreshSources()
    }
}

struct SourcesCellView: View {
    let source: AppSource

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: source.iconURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "globe")
                        .foregroundStyle(SignFlowTheme.accent)
                }
            }
            .frame(width: 44, height: 44)
            .background(SignFlowTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.headline)
                Text(source.subtitle ?? source.url.host ?? source.url.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

struct SourcesAddView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    let onAdd: (AppSource) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/apps.json", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                } header: {
                    Text("Repository URL")
                } footer: {
                    Text("Paste an AltStore-compatible source URL that you are authorized to use.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Add") { add() }
                            .disabled(URL(string: urlString) == nil)
                    }
                }
            }
        }
    }

    private func add() {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.hasPrefix("http") == true else {
            errorMessage = "Enter a valid http(s) repository URL."
            return
        }
        isLoading = true
        onAdd(AppSource(name: url.host ?? "Repository", url: url))
        isLoading = false
    }
}
