import Foundation

enum LibraryAppKind: String, Codable, Sendable, CaseIterable {
    case imported
    case signed
}

struct LibraryAppRecord: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var kind: LibraryAppKind
    var displayName: String
    var bundleIdentifier: String
    var version: String
    var buildNumber: String
    var minimumOSVersion: String
    var originalFilename: String
    var filePath: String
    var sha256: String
    var byteSize: UInt64
    var sourceURLString: String?
    var sourceName: String?
    var iconRelativePath: String?
    var profileTypeRaw: String?
    var importedAt: Date
    var signedAt: Date?
    var expiresAt: Date?

    var fileURL: URL {
        URL(fileURLWithPath: filePath)
    }

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt < Date()
    }
}

protocol LibraryStoring: Sendable {
    func listApps() async throws -> [LibraryAppRecord]
    func save(_ record: LibraryAppRecord) async throws
    func delete(ids: Set<UUID>) async throws
    func app(id: UUID) async throws -> LibraryAppRecord?
    func clearAll(deleteFiles: Bool) async throws
}
