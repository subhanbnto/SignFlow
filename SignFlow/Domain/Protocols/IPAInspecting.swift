import Foundation

protocol IPAInspecting: Sendable {
    func inspect(extractedPayloadURL: URL) async throws -> AppPackage
}
