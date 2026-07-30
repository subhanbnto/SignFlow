import Foundation
import Security
import OSLog

enum InstallerSettings {
    static let endpointURLKey = "installerBackendURL"
    static let retentionDisclosureAcknowledgedKey = "installerRetentionAcknowledged"
    static let defaultEndpointURLString = "https://signflow-installer.subhanhanif16.workers.dev"

    static var endpointURLString: String {
        get { UserDefaults.standard.string(forKey: endpointURLKey) ?? defaultEndpointURLString }
        set { UserDefaults.standard.set(newValue, forKey: endpointURLKey) }
    }

    static var endpointURL: URL? {
        let trimmed = endpointURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme == "https" else {
            return nil
        }
        return url
    }

    static var retentionAcknowledged: Bool {
        get { UserDefaults.standard.bool(forKey: retentionDisclosureAcknowledgedKey) }
        set { UserDefaults.standard.set(newValue, forKey: retentionDisclosureAcknowledgedKey) }
    }
}

actor InstallerAPITokenStore {
    private static let logger = Logger(subsystem: "com.bnto.signflow", category: "InstallerToken")
    private static let service = "com.bnto.signflow.installer-api"
    private static let account = "api-token"

    func save(token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        try delete()
        guard !trimmed.isEmpty else { return }

        let data = Data(trimmed.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SignFlowError.internalError(detail: "Could not save installer API token (\(status)).")
        }
    }

    func load() throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw SignFlowError.internalError(detail: "Could not read installer API token (\(status)).")
        }
        return String(data: data, encoding: .utf8)
    }

    func delete() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Self.logger.error("Failed to delete installer token (\(status))")
            throw SignFlowError.cleanupFailed(detail: "Could not delete installer API token (\(status)).")
        }
    }

    func hasToken() throws -> Bool {
        try load()?.isEmpty == false
    }
}
