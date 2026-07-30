import Foundation
import ZIPFoundation
import OSLog

struct IPARepackager: IPARepackaging {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "IPARepackager")

    func repackage(
        payloadParentURL: URL,
        outputURL: URL,
        compressionLevel: CompressionLevelSetting = .defaultLevel
    ) async throws -> URL {
        try Task.checkCancellation()

        let fm = FileManager.default
        if fm.fileExists(atPath: outputURL.path) {
            try fm.removeItem(at: outputURL)
        }

        let payloadURL = payloadParentURL.appendingPathComponent("Payload")
        guard fm.fileExists(atPath: payloadURL.path) else {
            throw SignFlowError.outputPackagingFailed(detail: "Payload directory missing before packaging.")
        }

        let staging = payloadParentURL.appendingPathComponent(".ipa-staging-\(UUID().uuidString)", isDirectory: true)
        let stagingPayload = staging.appendingPathComponent("Payload", isDirectory: true)
        defer { try? fm.removeItem(at: staging) }

        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        try fm.copyItem(at: payloadURL, to: stagingPayload)

        let method: CompressionMethod = {
            switch compressionLevel {
            case .none: return .none
            case .fastest, .defaultLevel, .best: return .deflate
            }
        }()

        do {
            try fm.zipItem(
                at: stagingPayload,
                to: outputURL,
                shouldKeepParent: true,
                compressionMethod: method
            )
        } catch {
            throw SignFlowError.outputPackagingFailed(detail: error.localizedDescription)
        }

        guard fm.fileExists(atPath: outputURL.path) else {
            throw SignFlowError.outputPackagingFailed(detail: "Output IPA was not created.")
        }

        Self.logger.info("Packaged IPA at \(outputURL.lastPathComponent, privacy: .public)")
        return outputURL
    }
}
