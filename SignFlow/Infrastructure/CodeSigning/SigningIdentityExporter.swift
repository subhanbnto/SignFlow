import Foundation
import Security
import OSLog

enum SigningIdentityExporter {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "IdentityExporter")

    struct ExportedMaterial {
        let certificateDER: Data
        let privateKeyPEM: Data
    }

    static func export(identity: SigningIdentity) throws -> ExportedMaterial {
        let query: [CFString: Any] = [
            kSecClass: kSecClassIdentity,
            kSecValuePersistentRef: identity.keychainReference,
            kSecReturnRef: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let item else {
            throw SignFlowError.missingSigningIdentity
        }

        let secIdentity = item as! SecIdentity

        var certificate: SecCertificate?
        guard SecIdentityCopyCertificate(secIdentity, &certificate) == errSecSuccess,
              let certificate else {
            throw SignFlowError.invalidCertificate(detail: "Could not load certificate from Keychain.")
        }
        let certDER = SecCertificateCopyData(certificate) as Data

        var privateKey: SecKey?
        guard SecIdentityCopyPrivateKey(secIdentity, &privateKey) == errSecSuccess,
              let privateKey else {
            throw SignFlowError.missingPrivateKey
        }

        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data? else {
            let detail = error?.takeRetainedValue().localizedDescription ?? "Key is not exportable."
            Self.logger.error("Private key export failed")
            throw SignFlowError.signingFailed(detail: "Could not export private key for signing: \(detail)")
        }

        let attrs = SecKeyCopyAttributes(privateKey) as? [CFString: Any]
        let pem = try privateKeyPEM(
            externalRepresentation: keyData,
            keyType: attrs?[kSecAttrKeyType] as? String,
            keySizeInBits: (attrs?[kSecAttrKeySizeInBits] as? NSNumber)?.intValue
        )

        return ExportedMaterial(certificateDER: certDER, privateKeyPEM: pem)
    }

    /// `SecKeyCopyExternalRepresentation` returns PKCS#1 for RSA keys and a raw
    /// X9.63 blob (04 || X || Y || K) for elliptic curve keys. Neither matches the
    /// PKCS#8 structure implied by a plain `PRIVATE KEY` header, so each type needs
    /// its own PEM wrapper before an OpenSSL-based signer can decode it.
    static func privateKeyPEM(
        externalRepresentation keyData: Data,
        keyType: String?,
        keySizeInBits: Int?
    ) throws -> Data {
        let rsa = kSecAttrKeyTypeRSA as String
        let ellipticCurves = [kSecAttrKeyTypeECSECPrimeRandom as String, kSecAttrKeyTypeEC as String]

        if keyType == rsa {
            return pemEncode(keyData, type: "RSA PRIVATE KEY")
        }

        if let keyType, ellipticCurves.contains(keyType) {
            let der = try sec1ECPrivateKey(fromX963: keyData, keySizeInBits: keySizeInBits)
            return pemEncode(der, type: "EC PRIVATE KEY")
        }

        Self.logger.error("Unsupported private key type for export")
        throw SignFlowError.signingFailed(
            detail: "The signing identity uses a private key type that SignFlow cannot export."
        )
    }

    /// Builds a SEC1 `ECPrivateKey` structure from Apple's raw X9.63 representation.
    private static func sec1ECPrivateKey(fromX963 raw: Data, keySizeInBits: Int?) throws -> Data {
        let fieldSize = keySizeInBits.map { ($0 + 7) / 8 } ?? ((raw.count - 1) / 3)

        guard fieldSize > 0,
              raw.count == 1 + 3 * fieldSize,
              raw.first == 0x04,
              let curveOID = curveOID(forFieldSize: fieldSize) else {
            throw SignFlowError.signingFailed(
                detail: "The elliptic curve private key has an unexpected layout."
            )
        }

        let publicPoint = raw.prefix(1 + 2 * fieldSize)
        let scalar = raw.suffix(fieldSize)

        var body = Data()
        body += der(tag: 0x02, content: Data([0x01]))
        body += der(tag: 0x04, content: Data(scalar))
        body += der(tag: 0xA0, content: curveOID)
        body += der(tag: 0xA1, content: der(tag: 0x03, content: Data([0x00]) + publicPoint))
        return der(tag: 0x30, content: body)
    }

    private static func curveOID(forFieldSize fieldSize: Int) -> Data? {
        switch fieldSize {
        case 32: return Data([0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07])
        case 48: return Data([0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22])
        case 66: return Data([0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x23])
        default: return nil
        }
    }

    private static func der(tag: UInt8, content: Data) -> Data {
        var encoded = Data([tag])
        if content.count < 0x80 {
            encoded.append(UInt8(content.count))
        } else {
            var lengthBytes: [UInt8] = []
            var remaining = content.count
            while remaining > 0 {
                lengthBytes.insert(UInt8(remaining & 0xFF), at: 0)
                remaining >>= 8
            }
            encoded.append(UInt8(0x80 | lengthBytes.count))
            encoded.append(contentsOf: lengthBytes)
        }
        encoded.append(content)
        return encoded
    }

    private static func pemEncode(_ data: Data, type: String) -> Data {
        let base64 = data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        let pem = "-----BEGIN \(type)-----\n\(base64)\n-----END \(type)-----\n"
        return Data(pem.utf8)
    }
}
