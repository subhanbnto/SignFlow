import SwiftUI

struct SourceAppsView: View {
    let sources: [AppSource]

    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var apps: [SourceApp] = []
    @State private var news: [SourceNewsItem] = []
    @State private var searchText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var downloadingID: UUID?

    private var filteredApps: [SourceApp] {
        if searchText.isEmpty { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
                || ($0.developerName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var title: String {
        sources.count == 1 ? (sources.first?.name ?? "Apps") : "All Repositories"
    }

    var body: some View {
        List {
            if !news.isEmpty {
                Section("News") {
                    ForEach(news.prefix(8)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.headline)
                            if let caption = item.caption {
                                Text(caption).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                ForEach(filteredApps) { app in
                    Button {
                        router.navigate(to: .sourceAppDetail(app))
                    } label: {
                        SourceAppCellView(app: app, isDownloading: downloadingID == app.id) {
                            Task { await download(app) }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView("Loading apps…")
            } else if filteredApps.isEmpty {
                ContentUnavailableView(
                    "No Apps",
                    systemImage: "app.dashed",
                    description: Text(errorMessage ?? "This source did not return any applications.")
                )
            }
        }
        .searchable(text: $searchText, prompt: "Search")
        .navigationTitle(title)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        var gathered: [SourceApp] = []
        var gatheredNews: [SourceNewsItem] = []
        for source in sources {
            do {
                let catalog = try await environment.sourceFetcher.fetchCatalog(for: source)
                try? await environment.sourceStore.updateSource(catalog.source)
                gathered.append(contentsOf: catalog.apps)
                gatheredNews.append(contentsOf: catalog.news)
            } catch {
                errorMessage = (error as? SignFlowError)?.explanation ?? error.localizedDescription
            }
        }
        apps = gathered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        news = gatheredNews
        await environment.refreshSources()
    }

    private func download(_ app: SourceApp) async {
        guard let version = app.latestVersion else { return }
        downloadingID = app.id
        defer { downloadingID = nil }
        do {
            let local = try await environment.downloadManager.startDownload(
                from: version.downloadURL,
                suggestedName: "\(app.name).ipa"
            )
            router.navigate(to: .inspecting(local))
        } catch {
            errorMessage = (error as? SignFlowError)?.explanation ?? error.localizedDescription
        }
    }
}

struct SourceAppCellView: View {
    let app: SourceApp
    let isDownloading: Bool
    let onDownload: () -> Void

    @AppStorage(SignFlowPreferences.storeCellAppearanceKey) private var cellStyle = 0

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: app.iconURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "app.fill")
                        .foregroundStyle(SignFlowTheme.accent)
                }
            }
            .frame(width: 52, height: 52)
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.headline).foregroundStyle(.primary)
                Text(app.developerName ?? app.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if cellStyle == 1, let description = app.localizedDescription {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                } else if let version = app.latestVersion?.version {
                    Text("v\(version)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button(action: onDownload) {
                if isDownloading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(SignFlowTheme.accent)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct SourceAppDetailView: View {
    let app: SourceApp
    @Environment(AppRouter.self) private var router
    @Environment(AppEnvironment.self) private var environment
    @State private var isDownloading = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    AsyncImage(url: app.iconURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "app.fill")
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name).font(.title3.bold())
                        Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                        if let developer = app.developerName {
                            Text(developer).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let description = app.localizedDescription {
                Section("About") {
                    Text(description)
                }
            }

            Section("Versions") {
                ForEach(app.versions) { version in
                    Button {
                        Task { await download(version) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(version.version).font(.headline)
                                if let date = version.date {
                                    Text(date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(SignFlowTheme.accent)
                        }
                    }
                }
            }

            if !app.screenshotURLs.isEmpty {
                Section("Screenshots") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(app.screenshotURLs, id: \.self) { url in
                                AsyncImage(url: url) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFit()
                                    } else {
                                        Color.secondary.opacity(0.1)
                                    }
                                }
                                .frame(width: 160, height: 280)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle(app.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if isDownloading {
                    ProgressView()
                } else {
                    Button("Get") {
                        if let latest = app.latestVersion {
                            Task { await download(latest) }
                        }
                    }
                }
            }
        }
    }

    private func download(_ version: SourceAppVersion) async {
        isDownloading = true
        defer { isDownloading = false }
        do {
            let local = try await environment.downloadManager.startDownload(
                from: version.downloadURL,
                suggestedName: "\(app.name)-\(version.version).ipa"
            )
            router.navigate(to: .inspecting(local))
        } catch {
            errorMessage = (error as? SignFlowError)?.explanation ?? error.localizedDescription
        }
    }
}
