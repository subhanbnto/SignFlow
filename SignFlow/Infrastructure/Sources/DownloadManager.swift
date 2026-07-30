import Foundation
import OSLog

actor DownloadManager {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "DownloadManager")

    struct DownloadItem: Identifiable, Sendable {
        let id: String
        let url: URL
        var progress: Double
        var filename: String
        var isFinished: Bool
        var localURL: URL?
        var errorMessage: String?
    }

    private(set) var items: [DownloadItem] = []
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func startDownload(from url: URL, suggestedName: String? = nil) async throws -> URL {
        let id = UUID().uuidString
        let filename = suggestedName ?? url.lastPathComponent
        items.append(DownloadItem(id: id, url: url, progress: 0, filename: filename, isFinished: false))

        let (tempURL, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            update(id: id, progress: 0, finished: true, local: nil, error: "Download failed.")
            throw SignFlowError.internalError(detail: "Download failed for \(url.absoluteString).")
        }

        let downloads = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let destination = downloads.appendingPathComponent(filename.isEmpty ? "download.ipa" : filename)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        update(id: id, progress: 1, finished: true, local: destination, error: nil)
        Self.logger.info("Downloaded \(destination.lastPathComponent, privacy: .public)")
        return destination
    }

    private func update(id: String, progress: Double, finished: Bool, local: URL?, error: String?) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].progress = progress
        items[index].isFinished = finished
        items[index].localURL = local
        items[index].errorMessage = error
    }
}
