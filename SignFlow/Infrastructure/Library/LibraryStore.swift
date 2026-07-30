import Foundation
import OSLog

actor LibraryStore: LibraryStoring {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "LibraryStore")
    private static let metadataFileName = "library-apps.json"
    private static let folderName = "SignFlow"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func listApps() async throws -> [LibraryAppRecord] {
        let records = try hydrate(loadMetadata())
        try? saveMetadata(records)
        return records.sorted { lhs, rhs in
            let lhsDate = lhs.signedAt ?? lhs.importedAt
            let rhsDate = rhs.signedAt ?? rhs.importedAt
            return lhsDate > rhsDate
        }
    }

    func save(_ record: LibraryAppRecord) async throws {
        var records = try loadMetadata()
        records.removeAll { $0.id == record.id }
        // Replace same file path entries to avoid duplicates after re-import.
        records.removeAll { $0.filePath == record.filePath && $0.kind == record.kind }
        records.append(record)
        try saveMetadata(records)
        Self.logger.info("Saved library app \(record.displayName, privacy: .public)")
    }

    func delete(ids: Set<UUID>) async throws {
        var records = try loadMetadata()
        let doomed = records.filter { ids.contains($0.id) }
        for record in doomed {
            try? fileManager.removeItem(at: record.fileURL)
        }
        records.removeAll { ids.contains($0.id) }
        try saveMetadata(records)
    }

    func app(id: UUID) async throws -> LibraryAppRecord? {
        try await listApps().first { $0.id == id }
    }

    func clearAll(deleteFiles: Bool) async throws {
        let records = try loadMetadata()
        if deleteFiles {
            for record in records {
                try? fileManager.removeItem(at: record.fileURL)
            }
        }
        try saveMetadata([])
    }

    func recordFromPackage(_ package: AppPackage, kind: LibraryAppKind, sourceName: String? = nil) -> LibraryAppRecord {
        LibraryAppRecord(
            id: package.id,
            kind: kind,
            displayName: package.displayName,
            bundleIdentifier: package.primaryBundleIdentifier,
            version: package.version,
            buildNumber: package.buildNumber,
            minimumOSVersion: package.minimumOSVersion,
            originalFilename: package.originalFilename,
            filePath: package.sourceURL.path,
            sha256: package.sha256,
            byteSize: package.fileSize,
            sourceURLString: nil,
            sourceName: sourceName,
            iconRelativePath: nil,
            profileTypeRaw: nil,
            importedAt: Date(),
            signedAt: kind == .signed ? Date() : nil,
            expiresAt: nil
        )
    }

    func recordFromSigningResult(_ result: SigningJobResult) -> LibraryAppRecord {
        LibraryAppRecord(
            id: result.id,
            kind: .signed,
            displayName: result.displayName,
            bundleIdentifier: result.primaryBundleIdentifier,
            version: result.bundleVersion,
            buildNumber: result.bundleVersion,
            minimumOSVersion: "",
            originalFilename: result.outputFilename,
            filePath: result.outputURL.path,
            sha256: result.outputSHA256,
            byteSize: result.byteSize,
            sourceURLString: nil,
            sourceName: nil,
            iconRelativePath: nil,
            profileTypeRaw: result.profileType.rawValue,
            importedAt: result.signedAt,
            signedAt: result.signedAt,
            expiresAt: nil
        )
    }

    // MARK: - Persistence

    private func metadataURL() throws -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent(Self.folderName, isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = dir
        try? mutable.setResourceValues(values)
        return dir.appendingPathComponent(Self.metadataFileName)
    }

    private func loadMetadata() throws -> [LibraryAppRecord] {
        let url = try metadataURL()
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([LibraryAppRecord].self, from: data)
    }

    private func saveMetadata(_ records: [LibraryAppRecord]) throws {
        let url = try metadataURL()
        let data = try JSONEncoder().encode(records)
        try data.write(to: url, options: .atomic)
    }

    private func hydrate(_ records: [LibraryAppRecord]) -> [LibraryAppRecord] {
        records.compactMap { record in
            if fileManager.fileExists(atPath: record.filePath) {
                return record
            }
            // Heal Documents/Imports or Exports relative to current container.
            if let healed = healPath(for: record) {
                return healed
            }
            Self.logger.error("Dropping missing library app \(record.displayName, privacy: .public)")
            return nil
        }
    }

    private func healPath(for record: LibraryAppRecord) -> LibraryAppRecord? {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let candidates = [
            docs.appendingPathComponent("Imports").appendingPathComponent(record.originalFilename),
            docs.appendingPathComponent("Exports").appendingPathComponent(record.originalFilename),
            docs.appendingPathComponent(record.originalFilename)
        ]
        guard let match = candidates.first(where: { fileManager.fileExists(atPath: $0.path) }) else {
            return nil
        }
        var healed = record
        healed.filePath = match.path
        return healed
    }
}
