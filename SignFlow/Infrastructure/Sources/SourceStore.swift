import Foundation
import OSLog

actor SourceStore: SourceStoring {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "SourceStore")
    private static let metadataFileName = "sources.json"
    private static let folderName = "SignFlow"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func listSources() async throws -> [AppSource] {
        try loadMetadata().sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addSource(_ source: AppSource) async throws {
        var sources = try loadMetadata()
        if sources.contains(where: { $0.url == source.url }) {
            throw SignFlowError.internalError(detail: "That repository URL is already added.")
        }
        sources.append(source)
        try saveMetadata(sources)
        Self.logger.info("Added source \(source.name, privacy: .public)")
    }

    func deleteSource(id: UUID) async throws {
        var sources = try loadMetadata()
        sources.removeAll { $0.id == id }
        try saveMetadata(sources)
    }

    func updateSource(_ source: AppSource) async throws {
        var sources = try loadMetadata()
        guard let index = sources.firstIndex(where: { $0.id == source.id }) else { return }
        sources[index] = source
        try saveMetadata(sources)
    }

    func clearAll() async throws {
        try saveMetadata([])
    }

    private func metadataURL() throws -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent(Self.folderName, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(Self.metadataFileName)
    }

    private func loadMetadata() throws -> [AppSource] {
        let url = try metadataURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([AppSource].self, from: data)
    }

    private func saveMetadata(_ sources: [AppSource]) throws {
        let data = try JSONEncoder().encode(sources)
        try data.write(to: try metadataURL(), options: .atomic)
    }
}
