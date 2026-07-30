import Foundation

enum SigningAppearanceMode: String, Codable, Sendable, CaseIterable {
    case `default`
    case light
    case dark

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum MinimumAppRequirement: String, Codable, Sendable, CaseIterable {
    case unchanged
    case iOS15
    case iOS16
    case iOS17
    case iOS18

    var displayName: String {
        switch self {
        case .unchanged: return "Unchanged"
        case .iOS15: return "15.0"
        case .iOS16: return "16.0"
        case .iOS17: return "17.0"
        case .iOS18: return "18.0"
        }
    }

    var versionString: String? {
        switch self {
        case .unchanged: return nil
        case .iOS15: return "15.0"
        case .iOS16: return "16.0"
        case .iOS17: return "17.0"
        case .iOS18: return "18.0"
        }
    }
}

struct SigningOptions: Hashable, Codable, Sendable {
    var displayNameRules: [String: String] = [:]
    var identifierRules: [String: String] = [:]
    var ppqProtection = false
    var ppqString: String = SigningOptions.makePPQString()
    var appAppearance: SigningAppearanceMode = .default
    var minimumAppRequirement: MinimumAppRequirement = .unchanged
    var fileSharing = false
    var itunesFileSharing = false
    var proMotion = false
    var gameMode = false
    var ipadFullscreen = false
    var removeURLScheme = false
    var removeProvisioning = false
    var forceLocalizeDisplayName = false
    var installAfterSigning = true
    var deleteImportedAfterSigning = false
    var disableLiquidGlass = false
    var enableLiquidGlass = false
    var injectIntoExtensions = false
    var tweakPaths: [String] = []
    var removeDylibRelativePaths: [String] = []

    static func makePPQString(length: Int = 8) -> String {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<length).map { _ in alphabet.randomElement()! })
    }

    func resolvedDisplayName(for original: String) -> String? {
        displayNameRules[original]
    }

    func resolvedIdentifier(for original: String) -> String? {
        if let mapped = identifierRules[original] {
            return mapped
        }
        guard ppqProtection else { return nil }
        return "\(original).\(ppqString)"
    }
}

enum CompressionLevelSetting: Int, Codable, Sendable, CaseIterable {
    case none = 0
    case fastest = 1
    case defaultLevel = 2
    case best = 3

    var displayName: String {
        switch self {
        case .none: return "None"
        case .fastest: return "Fastest"
        case .defaultLevel: return "Default"
        case .best: return "Best"
        }
    }
}

enum InstallationMethodSetting: Int, Codable, Sendable, CaseIterable {
    case server = 0
    case idevice = 1

    var displayName: String {
        switch self {
        case .server: return "Server"
        case .idevice: return "idevice (Advanced)"
        }
    }
}

enum AppearanceStyleSetting: Int, Codable, Sendable, CaseIterable {
    case system = 0
    case light = 1
    case dark = 2

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

enum SignFlowPreferences {
    static let signingOptionsKey = "signflow.signingOptions"
    static let compressionLevelKey = "signflow.compressionLevel"
    static let showShareSheetKey = "signflow.showShareSheetOnExport"
    static let installationMethodKey = "signflow.installationMethod"
    static let appearanceStyleKey = "signflow.appearanceStyle"
    static let storeCellAppearanceKey = "signflow.storeCellAppearance"
    static let selectedIdentityIDKey = "signflow.selectedIdentityID"
    static let selectedProfileIDKey = "signflow.selectedProfileID"

    static var signingOptions: SigningOptions {
        get {
            guard let data = UserDefaults.standard.data(forKey: signingOptionsKey),
                  let decoded = try? JSONDecoder().decode(SigningOptions.self, from: data) else {
                return SigningOptions()
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: signingOptionsKey)
            }
        }
    }

    static var compressionLevel: CompressionLevelSetting {
        get { CompressionLevelSetting(rawValue: UserDefaults.standard.integer(forKey: compressionLevelKey)) ?? .defaultLevel }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: compressionLevelKey) }
    }

    static var showShareSheetOnExport: Bool {
        get { UserDefaults.standard.bool(forKey: showShareSheetKey) }
        set { UserDefaults.standard.set(newValue, forKey: showShareSheetKey) }
    }

    static var installationMethod: InstallationMethodSetting {
        get { InstallationMethodSetting(rawValue: UserDefaults.standard.integer(forKey: installationMethodKey)) ?? .server }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: installationMethodKey) }
    }

    static var appearanceStyle: AppearanceStyleSetting {
        get { AppearanceStyleSetting(rawValue: UserDefaults.standard.integer(forKey: appearanceStyleKey)) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: appearanceStyleKey) }
    }

    static var storeCellAppearance: Int {
        get { UserDefaults.standard.integer(forKey: storeCellAppearanceKey) }
        set { UserDefaults.standard.set(newValue, forKey: storeCellAppearanceKey) }
    }
}
