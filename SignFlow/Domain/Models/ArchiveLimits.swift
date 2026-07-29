import Foundation

struct ArchiveLimits: Sendable {
    let maxCompressedSize: UInt64
    let maxExtractedSize: UInt64
    let maxEntryCount: Int
    let maxDirectoryDepth: Int
    let maxSingleFileSize: UInt64
    let maxCompressionRatio: Double

    static let `default` = ArchiveLimits(
        maxCompressedSize: 4_000_000_000,       // 4 GB
        maxExtractedSize: 8_000_000_000,         // 8 GB
        maxEntryCount: 100_000,
        maxDirectoryDepth: 30,
        maxSingleFileSize: 2_000_000_000,        // 2 GB
        maxCompressionRatio: 200.0
    )

    static let testing = ArchiveLimits(
        maxCompressedSize: 10_000_000,           // 10 MB
        maxExtractedSize: 50_000_000,            // 50 MB
        maxEntryCount: 500,
        maxDirectoryDepth: 10,
        maxSingleFileSize: 5_000_000,            // 5 MB
        maxCompressionRatio: 50.0
    )
}
