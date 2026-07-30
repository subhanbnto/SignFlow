import Foundation
import OSLog

/// Independent AltStore / AltStore 2.0 source client (not derived from Feather/AltSourceKit).
actor AltStoreSourceFetcher: SourceFetching {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "AltStoreSourceFetcher")
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCatalog(for source: AppSource) async throws -> SourceCatalog {
        var request = URLRequest(url: source.url)
        request.timeoutInterval = 45
        request.setValue("SignFlow/0.1", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SignFlowError.internalError(detail: "Could not download repository JSON.")
        }

        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            throw SignFlowError.internalError(detail: "Repository JSON root must be an object.")
        }

        let name = (root["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? source.name
        let identifier = root["identifier"] as? String
        let subtitle = root["subtitle"] as? String ?? root["description"] as? String
        let iconURL = Self.url(from: root["iconURL"])
        let website = Self.url(from: root["website"])
        let tint = root["tintColor"] as? String

        var updated = source
        updated.name = name.isEmpty ? source.name : name
        updated.identifier = identifier ?? source.identifier
        updated.subtitle = subtitle
        updated.iconURL = iconURL
        updated.website = website
        updated.tintColorHex = tint
        updated.lastFetchedAt = Date()

        let apps = parseApps(root["apps"] as? [[String: Any]] ?? [], source: updated)
        let news = parseNews(root["news"] as? [[String: Any]] ?? [], sourceID: updated.id)

        Self.logger.info("Fetched \(apps.count, privacy: .public) apps from \(updated.name, privacy: .public)")
        return SourceCatalog(source: updated, apps: apps, news: news)
    }

    // MARK: - Parsing

    private func parseApps(_ items: [[String: Any]], source: AppSource) -> [SourceApp] {
        items.compactMap { item in
            guard let name = item["name"] as? String,
                  let bundleID = item["bundleIdentifier"] as? String else { return nil }

            let versions: [SourceAppVersion]
            if let versionObjects = item["versions"] as? [[String: Any]], !versionObjects.isEmpty {
                versions = versionObjects.compactMap { versionItem in
                    guard let version = versionItem["version"] as? String,
                          let download = Self.url(from: versionItem["downloadURL"]) else { return nil }
                    return SourceAppVersion(
                        version: version,
                        date: Self.date(from: versionItem["date"] ?? versionItem["dateAdded"]),
                        localizedDescription: versionItem["localizedDescription"] as? String,
                        downloadURL: download,
                        size: Self.uint64(from: versionItem["size"]),
                        minimumOSVersion: versionItem["minOSVersion"] as? String
                            ?? versionItem["minimumOSVersion"] as? String
                    )
                }
            } else if let download = Self.url(from: item["downloadURL"]),
                      let version = item["version"] as? String {
                versions = [
                    SourceAppVersion(
                        version: version,
                        date: Self.date(from: item["versionDate"] ?? item["date"]),
                        localizedDescription: item["versionDescription"] as? String,
                        downloadURL: download,
                        size: Self.uint64(from: item["size"]),
                        minimumOSVersion: item["minOSVersion"] as? String
                    )
                ]
            } else {
                versions = []
            }

            guard !versions.isEmpty else { return nil }

            let screenshots = ((item["screenshotURLs"] as? [Any]) ?? [])
                .compactMap(Self.url(from:))

            return SourceApp(
                sourceID: source.id,
                sourceName: source.name,
                name: name,
                bundleIdentifier: bundleID,
                developerName: item["developerName"] as? String,
                localizedDescription: item["localizedDescription"] as? String ?? item["subtitle"] as? String,
                iconURL: Self.url(from: item["iconURL"]),
                screenshotURLs: screenshots,
                versions: versions,
                tintColorHex: item["tintColor"] as? String
            )
        }
    }

    private func parseNews(_ items: [[String: Any]], sourceID: UUID) -> [SourceNewsItem] {
        items.compactMap { item in
            guard let title = item["title"] as? String else { return nil }
            return SourceNewsItem(
                sourceID: sourceID,
                title: title,
                caption: item["caption"] as? String,
                date: Self.date(from: item["date"]),
                imageURL: Self.url(from: item["imageURL"]),
                url: Self.url(from: item["url"]),
                tintColorHex: item["tintColor"] as? String
            )
        }
    }

    private static func url(from value: Any?) -> URL? {
        if let string = value as? String, let url = URL(string: string), url.scheme != nil {
            return url
        }
        return nil
    }

    private static func uint64(from value: Any?) -> UInt64? {
        if let number = value as? NSNumber { return number.uint64Value }
        if let int = value as? Int { return UInt64(int) }
        if let string = value as? String, let int = UInt64(string) { return int }
        return nil
    }

    private static func date(from value: Any?) -> Date? {
        if let date = value as? Date { return date }
        guard let string = value as? String else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: string) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
