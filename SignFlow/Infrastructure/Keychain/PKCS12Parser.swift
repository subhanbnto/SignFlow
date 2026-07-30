import Foundation
import Security
import OSLog

/// Parses PKCS#12 data into a SecIdentity + certificate without Keychain storage.
enum PKCS12Parser {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "PKCS12Parser")

    struct ParsedIdentity {
        let identity: SecIdentity
        let certificate: SecCertificate
        let metadata: CertificateMetadataExtractor.Metadata
    }

    static func parse(data: Data, password: String) throws -> ParsedIdentity {
        let options: [CFString: Any] = [
            kSecImportExportPassphrase: password
        ]

        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)

        switch status {
        case errSecSuccess:
            break
        case errSecAuthFailed:
            throw SignFlowError.incorrectP12Password
        default:
            throw SignFlowError.invalidP12(detail: "Security framework returned status \(status).")
        }

        guard let array = items as? [[CFString: Any]], let first = array.first else {
            throw SignFlowError.missingSigningIdentity
        }

        guard let identityRef = first[kSecImportItemIdentity] else {
            throw SignFlowError.missingSigningIdentity
        }

        let identity = identityRef as! SecIdentity

        var privateKey: SecKey?
        let keyStatus = SecIdentityCopyPrivateKey(identity, &privateKey)
        guard keyStatus == errSecSuccess, privateKey != nil else {
            throw SignFlowError.missingPrivateKey
        }

        var certificate: SecCertificate?
        let certStatus = SecIdentityCopyCertificate(identity, &certificate)
        guard certStatus == errSecSuccess, let cert = certificate else {
            throw SignFlowError.invalidCertificate(detail: "Could not extract certificate from identity.")
        }

        let metadata = try CertificateMetadataExtractor.extract(from: cert)
        return ParsedIdentity(identity: identity, certificate: cert, metadata: metadata)
    }
}
