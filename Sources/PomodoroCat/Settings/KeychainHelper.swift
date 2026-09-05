import Foundation
import Security

/// The Discord webhook URL is a secret (anyone with it can post to the channel),
/// so it lives in Keychain rather than UserDefaults.
enum KeychainHelper {
    private static let service = "com.local.pomodorocat"
    private static let account = "discordWebhookURL"

    static func saveWebhookURL(_ urlString: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)

        guard !urlString.isEmpty else { return }
        var newItem = query
        newItem[kSecValueData as String] = Data(urlString.utf8)
        SecItemAdd(newItem as CFDictionary, nil)
    }

    static func loadWebhookURL() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
