import XCTest
import Security
@testable import SignFlow

final class SigningIdentityExporterTests: XCTestCase {
    private func pemString(_ data: Data) -> String {
        String(decoding: data, as: UTF8.self)
    }

    private func pemBody(_ data: Data) -> Data {
        let lines = pemString(data)
            .split(separator: "\n")
            .filter { !$0.hasPrefix("-----") }
        return Data(base64Encoded: lines.joined()) ?? Data()
    }

    func testRSAKeyUsesPKCS1Header() throws {
        let keyData = Data((0..<64).map { UInt8($0) })
        let pem = try SigningIdentityExporter.privateKeyPEM(
            externalRepresentation: keyData,
            keyType: kSecAttrKeyTypeRSA as String,
            keySizeInBits: 2048
        )

        let text = pemString(pem)
        XCTAssertTrue(text.hasPrefix("-----BEGIN RSA PRIVATE KEY-----\n"))
        XCTAssertTrue(text.hasSuffix("-----END RSA PRIVATE KEY-----\n"))
        XCTAssertFalse(text.contains("BEGIN PRIVATE KEY"))
        XCTAssertEqual(pemBody(pem), keyData)
    }

    func testECKeyIsWrappedInSEC1Structure() throws {
        let fieldSize = 32
        let x = Data(repeating: 0xA1, count: fieldSize)
        let y = Data(repeating: 0xB2, count: fieldSize)
        let scalar = Data(repeating: 0xC3, count: fieldSize)
        let raw = Data([0x04]) + x + y + scalar

        let pem = try SigningIdentityExporter.privateKeyPEM(
            externalRepresentation: raw,
            keyType: kSecAttrKeyTypeECSECPrimeRandom as String,
            keySizeInBits: 256
        )

        XCTAssertTrue(pemString(pem).hasPrefix("-----BEGIN EC PRIVATE KEY-----\n"))

        let der = pemBody(pem)
        XCTAssertEqual(der.first, 0x30)
        XCTAssertEqual(Array(der[2...4]), [0x02, 0x01, 0x01])

        let p256OID = Data([0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07])
        XCTAssertTrue(der.range(of: p256OID) != nil)
        XCTAssertTrue(der.range(of: scalar) != nil)
        XCTAssertTrue(der.range(of: Data([0x04]) + x + y) != nil)
    }

    func testECKeyWithUnexpectedLayoutThrows() {
        let raw = Data([0x04]) + Data(repeating: 0x01, count: 10)
        XCTAssertThrowsError(
            try SigningIdentityExporter.privateKeyPEM(
                externalRepresentation: raw,
                keyType: kSecAttrKeyTypeECSECPrimeRandom as String,
                keySizeInBits: 256
            )
        )
    }

    func testUnknownKeyTypeThrows() {
        XCTAssertThrowsError(
            try SigningIdentityExporter.privateKeyPEM(
                externalRepresentation: Data([0x00]),
                keyType: nil,
                keySizeInBits: nil
            )
        )
    }
}
