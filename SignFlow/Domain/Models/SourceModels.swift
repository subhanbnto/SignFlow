import Foundation

struct AppSource: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var url: URL
    var identifier: String?
    var subtitle: String?
    var iconURL: URL?
    var website: URL?
    var tintColorHex: String?
    var addedAt: Date
    var lastFetchedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        identifier: String? = nil,
        subtitle: String? = nil,
        iconURL: URL? = nil,
        website: URL? = nil,
        tintColorHex: String? = nil,
        addedAt: Date = Date(),
        lastFetchedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.identifier = identifier
        self.subtitle = subtitle
        self.iconURL = iconURL
        self.website = website
        self.tintColorHex = tintColorHex
        self.addedAt = addedAt
        self.lastFetchedAt = lastFetchedAt
    }
}

struct SourceAppVersion: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var version: String
    var date: Date?
    var localizedDescription: String?
    var downloadURL: URL
    var size: UInt64?
    var minimumOSVersion: String?

    init(
        id: UUID = UUID(),
        version: String,
        date: Date? = nil,
        localizedDescription: String? = nil,
        downloadURL: URL,
        size: UInt64? = nil,
        minimumOSVersion: String? = nil
    ) {
        self.id = id
        self.version = version
        self.date = date
        self.localizedDescription = localizedDescription
        self.downloadURL = downloadURL
        self.size = size
        self.minimumOSVersion = minimumOSVersion
    }
}

struct SourceApp: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var sourceID: UUID
    var sourceName: String
    var name: String
    var bundleIdentifier: String
    var developerName: String?
    var localizedDescription: String?
    var iconURL: URL?
    var screenshotURLs: [URL]
    var versions: [SourceAppVersion]
    var tintColorHex: String?

    var latestVersion: SourceAppVersion? {
        versions.first
    }

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        sourceName: String,
        name: String,
        bundleIdentifier: String,
        developerName: String? = nil,
        localizedDescription: String? = nil,
        iconURL: URL? = nil,
        screenshotURLs: [URL] = [],
        versions: [SourceAppVersion] = [],
        tintColorHex: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.developerName = developerName
        self.localizedDescription = localizedDescription
        self.iconURL = iconURL
        self.screenshotURLs = screenshotURLs
        self.versions = versions
        self.tintColorHex = tintColorHex
    }
}

struct SourceNewsItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var sourceID: UUID
    var title: String
    var caption: String?
    var date: Date?
    var imageURL: URL?
    var url: URL?
    var tintColorHex: String?

    init(
        id: UUID = UUID(),
        sourceID: UUID,
        title: String,
        caption: String? = nil,
        date: Date? = nil,
        imageURL: URL? = nil,
        url: URL? = nil,
        tintColorHex: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.title = title
        self.caption = caption
        self.date = date
        self.imageURL = imageURL
        self.url = url
        self.tintColorHex = tintColorHex
    }
}

struct SourceCatalog: Sendable {
    var source: AppSource
    var apps: [SourceApp]
    var news: [SourceNewsItem]
}

protocol SourceStoring: Sendable {
    func listSources() async throws -> [AppSource]
    func addSource(_ source: AppSource) async throws
    func deleteSource(id: UUID) async throws
    func updateSource(_ source: AppSource) async throws
    func clearAll() async throws
}

protocol SourceFetching: Sendable {
    func fetchCatalog(for source: AppSource) async throws -> SourceCatalog
}
