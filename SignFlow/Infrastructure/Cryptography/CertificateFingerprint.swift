import Foundation
import CryptoKit
import Security

enum CertificateFingerprint {
    /// SHA-256 fingerprint of DER-encoded certificate bytes, lowercase hex.
    static func sha256(of certificateData: Data) -> String {
        let digest = SHA256.hash(data: certificateData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256(of certificate: SecCertificate) -> String? {
        let data = SecCertificateCopyData(certificate) as Data
        return sha256(of: data)
    }
}
