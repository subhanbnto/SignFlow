import Foundation
import CryptoKit

enum SHA256Hasher {
    static let bufferSize = 1_048_576 // 1 MB

    static func hash(fileAt url: URL) async throws -> String {
        try Task.checkCancellation()

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            try Task.checkCancellation()
            guard let data = try handle.availableData(upToCount: bufferSize), !data.isEmpty else {
                break
            }
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension FileHandle {
    func availableData(upToCount count: Int) throws -> Data? {
        let data = try self.read(upToCount: count)
        return data
    }
}
