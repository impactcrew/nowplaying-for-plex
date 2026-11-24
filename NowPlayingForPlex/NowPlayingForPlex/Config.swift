import Foundation
import Security

struct PlexConfig: Codable {
    let plexServerUrl: String
    let plexToken: String
    let allowsLocalHTTP: Bool
}

enum SavedPlexConnection {
    case available(PlexConfig)
    case missing
    case needsReview
    case unavailable

    var config: PlexConfig? {
        if case let .available(config) = self { return config }
        return nil
    }
}

protocol PlexCredentialStore {
    func read(account: String) throws -> Data?
    func save(_ data: Data, account: String) throws
}

final class ConfigManager {
    static let shared = ConfigManager(defaults: .standard, store: KeychainPlexCredentialStore())

    private let connectionAccount = "plex-connection"
    private let legacyTokenAccount = "plex-token"
    private let serverURLKey = "plex-connection-server-url"
    private let legacyServerURLKey = "plex-server-url"
    private let debugTokenKey = "plex-token-debug"
    private let defaults: UserDefaults
    private let store: PlexCredentialStore

    init(defaults: UserDefaults, store: PlexCredentialStore) {
        self.defaults = defaults
        self.store = store
    }

    func loadConfig() -> PlexConfig? {
        loadSavedConnection().config
    }

    func loadSavedConnection() -> SavedPlexConnection {
        do {
            if let connection = try store.read(account: connectionAccount) {
                let config = try JSONDecoder().decode(PlexConfig.self, from: connection)
                saveServerHint(config.plexServerUrl)
                return .available(config)
            }

            return try migrateLegacyConfig()
        } catch {
            return .unavailable
        }
    }

    func saveConfig(serverUrl: String, token: String, allowsLocalHTTP: Bool = false) -> Bool {
        let config = PlexConfig(plexServerUrl: serverUrl, plexToken: token, allowsLocalHTTP: allowsLocalHTTP)
        do {
            let connection = try JSONEncoder().encode(config)
            try store.save(connection, account: connectionAccount)
        } catch {
            return false
        }

        // Keep the older app's Keychain entry and its associated address intact.
        saveServerHint(serverUrl)
        return true
    }

    func getServerUrl() -> String? {
        defaults.string(forKey: serverURLKey) ?? defaults.string(forKey: legacyServerURLKey)
    }

    private func saveServerHint(_ serverURL: String) {
        if defaults.string(forKey: serverURLKey) != serverURL {
            defaults.set(serverURL, forKey: serverURLKey)
        }
        if defaults.object(forKey: debugTokenKey) != nil {
            defaults.removeObject(forKey: debugTokenKey)
        }
    }

    private func migrateLegacyConfig() throws -> SavedPlexConnection {
        let legacyToken = try store.read(account: legacyTokenAccount).flatMap { String(data: $0, encoding: .utf8) }
        let debugToken = defaults.string(forKey: debugTokenKey)
        guard let token = legacyToken ?? debugToken else {
            return getServerUrl() == nil ? .missing : .needsReview
        }
        guard let serverURL = defaults.string(forKey: legacyServerURLKey) else { return .needsReview }
        // Debug and Release once shared an address field but wrote their tokens to different stores.
        // Different surviving tokens require the user to validate the address and token together.
        if let legacyToken, let debugToken, legacyToken != debugToken {
            return .needsReview
        }

        let allowsLocalHTTP = PlexServerAddress.isLegacyLocalHTTP(serverURL)
        let config = PlexConfig(plexServerUrl: serverURL, plexToken: token, allowsLocalHTTP: allowsLocalHTTP)
        if saveConfig(serverUrl: serverURL, token: token, allowsLocalHTTP: allowsLocalHTTP) {
            return .available(config)
        }

        // A legacy Release login can remain usable if migration fails temporarily.
        // A legacy Debug token must move to Keychain before it can be used.
        return legacyToken == nil ? .unavailable : .available(config)
    }
}

private struct KeychainPlexCredentialStore: PlexCredentialStore {
    private let service = "com.nowplayingforplex.credentials"

    func read(account: String) throws -> Data? {
        var query = key(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data else { throw KeychainError(status: errSecDecode) }
        return data
    }

    func save(_ data: Data, account: String) throws {
        let query = key(account)
        let changes = [kSecValueData as String: data]
        var status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(item as CFDictionary, nil)
            if status == errSecDuplicateItem {
                status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
            }
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private func key(_ account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

private struct KeychainError: Error {
    let status: OSStatus
}
