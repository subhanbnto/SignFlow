import Foundation
import Security

enum CertificateMetadataExtractor {
    struct Metadata {
        let commonName: String
        let issuer: String
        let serialNumber: String
        let validFrom: Date
        let expiresAt: Date
        let teamIdentifier: String?
        let certificateType: CertificateType
        let fingerprintSHA256: String
        let derData: Data
    }

    static func extract(from certificate: SecCertificate) throws -> Metadata {
        let derData = SecCertificateCopyData(certificate) as Data
        let fingerprint = CertificateFingerprint.sha256(of: derData)

        let summary = (SecCertificateCopySubjectSummary(certificate) as String?) ?? "Unknown Certificate"

        let parsed: X509Fields
        do {
            parsed = try X509DERParser.parse(derData)
        } catch {
            // Fall back to summary-only metadata if DER parsing fails
            return Metadata(
                commonName: summary,
                issuer: "Unknown Issuer",
                serialNumber: "unknown",
                validFrom: Date.distantPast,
                expiresAt: Date.distantFuture,
                teamIdentifier: extractTeamFromSummary(summary),
                certificateType: classifyFromSummary(summary),
                fingerprintSHA256: fingerprint,
                derData: derData
            )
        }

        let commonName = parsed.subjectCommonName ?? summary
        let teamID = parsed.subjectOrganizationalUnit ?? extractTeamFromSummary(commonName)

        return Metadata(
            commonName: commonName,
            issuer: parsed.issuerCommonName ?? "Unknown Issuer",
            serialNumber: parsed.serialNumber,
            validFrom: parsed.notBefore,
            expiresAt: parsed.notAfter,
            teamIdentifier: teamID,
            certificateType: classifyFromSummary(commonName),
            fingerprintSHA256: fingerprint,
            derData: derData
        )
    }

    private static func extractTeamFromSummary(_ summary: String) -> String? {
        if let open = summary.lastIndex(of: "("),
           let close = summary.lastIndex(of: ")"),
           open < close {
            let team = String(summary[summary.index(after: open)..<close])
            if team.count == 10 { return team }
        }
        return nil
    }

    private static func classifyFromSummary(_ summary: String) -> CertificateType {
        let lower = summary.lowercased()
        if lower.contains("iphone distribution") || lower.contains("apple distribution") {
            return .distribution
        }
        if lower.contains("iphone developer") || lower.contains("apple development") {
            return .development
        }
        if lower.contains("enterprise") || lower.contains("in-house") {
            return .enterprise
        }
        return .unknown
    }
}

// MARK: - Minimal X.509 DER parser

struct X509Fields {
    var serialNumber: String = "unknown"
    var issuerCommonName: String?
    var subjectCommonName: String?
    var subjectOrganizationalUnit: String?
    var notBefore: Date = .distantPast
    var notAfter: Date = .distantFuture
}

enum X509DERParser {
    static func parse(_ data: Data) throws -> X509Fields {
        var cursor = 0
        // Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm, signature }
        let cert = try readSequence(data, cursor: &cursor)
        var tbsCursor = 0
        let tbs = try readSequence(cert, cursor: &tbsCursor)

        var fields = X509Fields()
        var pos = 0

        // Optional version [0]
        if pos < tbs.count && tbs[pos] == 0xA0 {
            _ = try readTagged(tbs, tag: 0xA0, cursor: &pos)
        }

        // Serial number INTEGER
        let serialBytes = try readInteger(tbs, cursor: &pos)
        fields.serialNumber = serialBytes.map { String(format: "%02x", $0) }.joined()

        // Signature algorithm
        _ = try readSequence(tbs, cursor: &pos)

        // Issuer Name
        let issuer = try readSequence(tbs, cursor: &pos)
        fields.issuerCommonName = extractNameComponent(issuer, oid: [2, 5, 4, 3])

        // Validity SEQUENCE { notBefore, notAfter }
        let validity = try readSequence(tbs, cursor: &pos)
        var vPos = 0
        fields.notBefore = try readTime(validity, cursor: &vPos)
        fields.notAfter = try readTime(validity, cursor: &vPos)

        // Subject Name
        let subject = try readSequence(tbs, cursor: &pos)
        fields.subjectCommonName = extractNameComponent(subject, oid: [2, 5, 4, 3])
        fields.subjectOrganizationalUnit = extractNameComponent(subject, oid: [2, 5, 4, 11])

        return fields
    }

    // MARK: - ASN.1 primitives

    private static func readLength(_ data: Data, cursor: inout Int) throws -> Int {
        guard cursor < data.count else { throw ParseError.truncated }
        let first = Int(data[cursor])
        cursor += 1
        if first & 0x80 == 0 { return first }
        let count = first & 0x7F
        guard count > 0, count <= 4, cursor + count <= data.count else { throw ParseError.truncated }
        var length = 0
        for _ in 0..<count {
            length = (length << 8) | Int(data[cursor])
            cursor += 1
        }
        return length
    }

    private static func readTLV(_ data: Data, expectedTag: UInt8, cursor: inout Int) throws -> Data {
        guard cursor < data.count else { throw ParseError.truncated }
        let tag = data[cursor]
        cursor += 1
        guard tag == expectedTag else { throw ParseError.unexpectedTag(expected: expectedTag, got: tag) }
        let length = try readLength(data, cursor: &cursor)
        guard cursor + length <= data.count else { throw ParseError.truncated }
        let content = data.subdata(in: cursor..<(cursor + length))
        cursor += length
        return content
    }

    private static func readSequence(_ data: Data, cursor: inout Int) throws -> Data {
        try readTLV(data, expectedTag: 0x30, cursor: &cursor)
    }

    private static func readTagged(_ data: Data, tag: UInt8, cursor: inout Int) throws -> Data {
        try readTLV(data, expectedTag: tag, cursor: &cursor)
    }

    private static func readInteger(_ data: Data, cursor: inout Int) throws -> Data {
        try readTLV(data, expectedTag: 0x02, cursor: &cursor)
    }

    private static func readTime(_ data: Data, cursor: inout Int) throws -> Date {
        guard cursor < data.count else { throw ParseError.truncated }
        let tag = data[cursor]
        // UTCTime (0x17) or GeneralizedTime (0x18)
        if tag == 0x17 || tag == 0x18 {
            let content = try readTLV(data, expectedTag: tag, cursor: &cursor)
            guard let string = String(data: content, encoding: .ascii) else { throw ParseError.invalidTime }
            return parseASN1Time(string, isUTC: tag == 0x17) ?? .distantPast
        }
        throw ParseError.unexpectedTag(expected: 0x17, got: tag)
    }

    private static func parseASN1Time(_ string: String, isUTC: Bool) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if isUTC {
            // YYMMDDHHMMSSZ
            formatter.dateFormat = "yyMMddHHmmss'Z'"
        } else {
            formatter.dateFormat = "yyyyMMddHHmmss'Z'"
        }
        return formatter.date(from: string)
    }

    /// Walk RDNSequence looking for a specific OID's value.
    private static func extractNameComponent(_ nameData: Data, oid: [UInt8]) -> String? {
        var pos = 0
        while pos < nameData.count {
            guard nameData[pos] == 0x31 else { break } // SET
            guard let rdn = try? readTLV(nameData, expectedTag: 0x31, cursor: &pos) else { break }
            var rPos = 0
            while rPos < rdn.count {
                guard let attr = try? readSequence(rdn, cursor: &rPos) else { break }
                var aPos = 0
                guard let oidBytes = try? readTLV(attr, expectedTag: 0x06, cursor: &aPos) else { continue }
                if Array(oidBytes) == encodeOID(oid) || matchesOID(oidBytes, oid) {
                    // Value is PrintableString (0x13), UTF8String (0x0C), or IA5String (0x16)
                    guard aPos < attr.count else { continue }
                    let valueTag = attr[aPos]
                    if let value = try? readTLV(attr, expectedTag: valueTag, cursor: &aPos),
                       let string = String(data: value, encoding: .utf8) ?? String(data: value, encoding: .ascii) {
                        return string
                    }
                }
            }
        }
        return nil
    }

    private static func matchesOID(_ bytes: Data, _ components: [UInt8]) -> Bool {
        // Compare encoded form
        Array(bytes) == encodeOID(components)
    }

    private static func encodeOID(_ components: [UInt8]) -> [UInt8] {
        // Simple encoder for OIDs like 2.5.4.3 — components given as full path integers that fit in UInt8 for our use
        // For 2.5.4.x: first byte = 40*2+5 = 85 = 0x55, then 4, then x
        guard components.count >= 2 else { return [] }
        var result: [UInt8] = [UInt8(components[0] * 40 + components[1])]
        for i in 2..<components.count {
            result.append(components[i])
        }
        return result
    }

    enum ParseError: Error {
        case truncated
        case unexpectedTag(expected: UInt8, got: UInt8)
        case invalidTime
    }
}
