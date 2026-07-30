import Foundation
import ZIPFoundation
import OSLog

final class SafeZIPExtractor: IPAExtracting, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "ZIPExtractor")

    func extract(
        archiveURL: URL,
        to destinationURL: URL,
        limits: ArchiveLimits
    ) async throws -> URL {
        try Task.checkCancellation()

        let fileSize = try self.fileSize(at: archiveURL)
        guard fileSize <= limits.maxCompressedSize else {
            throw SignFlowError.archiveInputTooLarge(sizeBytes: fileSize, limitBytes: limits.maxCompressedSize)
        }

        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw SignFlowError.invalidIPA(detail: "Could not open archive.")
        }

        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        var entryCount = 0
        var totalExtracted: UInt64 = 0

        for entry in archive {
            try Task.checkCancellation()

            entryCount += 1
            if entryCount > limits.maxEntryCount {
                throw SignFlowError.archiveExtractionLimitExceeded(
                    limit: "entry count (\(limits.maxEntryCount))",
                    actual: "\(entryCount)"
                )
            }

            let entryPath = entry.path
            let resolvedURL = try PathSanitizer.validate(entryPath: entryPath, relativeTo: destinationURL)

            let depth = PathSanitizer.depthOf(resolvedURL, relativeTo: destinationURL)
            if depth > limits.maxDirectoryDepth {
                throw SignFlowError.archiveExtractionLimitExceeded(
                    limit: "directory depth (\(limits.maxDirectoryDepth))",
                    actual: "\(depth)"
                )
            }

            switch entry.type {
            case .symlink:
                throw SignFlowError.unsafeSymbolicLink(path: entryPath)

            case .directory:
                try FileManager.default.createDirectory(at: resolvedURL, withIntermediateDirectories: true)

            case .file:
                let uncompressed = entry.uncompressedSize
                if uncompressed > limits.maxSingleFileSize {
                    throw SignFlowError.archiveExtractionLimitExceeded(
                        limit: "single file size (\(limits.maxSingleFileSize) bytes)",
                        actual: "\(uncompressed) bytes"
                    )
                }

                if entry.compressedSize > 0 {
                    let ratio = Double(uncompressed) / Double(entry.compressedSize)
                    if ratio > limits.maxCompressionRatio {
                        throw SignFlowError.archiveExtractionLimitExceeded(
                            limit: "compression ratio (\(limits.maxCompressionRatio))",
                            actual: String(format: "%.1f", ratio)
                        )
                    }
                }

                totalExtracted += UInt64(uncompressed)
                if totalExtracted > limits.maxExtractedSize {
                    throw SignFlowError.archiveExtractionLimitExceeded(
                        limit: "total extracted size (\(limits.maxExtractedSize) bytes)",
                        actual: "\(totalExtracted) bytes"
                    )
                }

                let parentDir = resolvedURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

                _ = try archive.extract(entry, to: resolvedURL)
            }
        }

        Self.logger.info("Extracted \(entryCount) entries, \(totalExtracted) bytes total")
        return destinationURL
    }

    private func fileSize(at url: URL) throws -> UInt64 {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return attrs[.size] as? UInt64 ?? 0
    }
}
