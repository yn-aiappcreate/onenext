import Foundation
import Security

/// Generates and persists a stable device identifier in the Keychain.
/// Survives app reinstalls (Keychain persists until device reset).
enum ClientId {

    private static let service = "com.ynlabs.tsugiichi"
    private static let account = "clientId"

    /// Returns the persisted client ID, creating one if needed.
    static var current: String {
        if let existing = load() {
            return existing
        }
        let newId = UUID().uuidString
        save(newId)
        return newId
    }

    // MARK: - Keychain helpers

    private static func save(_ value: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }
}
