import XCTest
@testable import SignFlow

/// Keychain write requires app entitlements not available to the unit-test host (-34018).
/// Full Keychain persistence is covered manually on device; PKCS#12 parsing and in-memory
/// store behavior are unit-tested separately.
final class P12ImporterTests: XCTestCase {
    func testImportRequiresKeychainEntitlement() async throws {
        let store = KeychainIdentityStore(requireUserPresence: false)
        let importer = P12Importer(store: store, workspaceManager: WorkspaceManager())

        do {
            _ = try await importer.importP12(
                from: CredentialFixtures.p12URL,
                password: CredentialFixtures.p12Password
            )
            // If Keychain is available (e.g. on device), import should succeed
            let listed = try await store.listIdentities()
            XCTAssertTrue(listed.contains { $0.fingerprintSHA256 == CredentialFixtures.expectedFingerprint })
            if let match = listed.first(where: { $0.fingerprintSHA256 == CredentialFixtures.expectedFingerprint }) {
                try await store.deleteIdentity(id: match.id)
            }
        } catch let error as SignFlowError {
            if case .internalError(let detail) = error, detail.contains("-34018") {
                throw XCTSkip("Keychain unavailable in unit-test host (errSecMissingEntitlement). PKCS12 parsing is covered by PKCS12ParserTests.")
            }
            throw error
        }
    }

    func testIncorrectPasswordBeforeKeychain() async {
        let store = KeychainIdentityStore()
        let importer = P12Importer(store: store, workspaceManager: WorkspaceManager())
        do {
            _ = try await importer.importP12(
                from: CredentialFixtures.p12URL,
                password: "wrong-password"
            )
            XCTFail("Should throw")
        } catch let error as SignFlowError {
            switch error {
            case .incorrectP12Password, .invalidP12:
                break
            default:
                XCTFail("Wrong error: \(error)")
            }
        } catch {
            XCTFail("Unexpected: \(error)")
        }
    }
}
