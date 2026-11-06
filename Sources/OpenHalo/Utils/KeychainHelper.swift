import Foundation
import Security
import CoreGraphics

public enum KeychainHelper {
    private static let serviceName = "com.openhalo.lockscreen.password"
    private static let accountName = NSUserName()

    public static func savePassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        deletePassword()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public static func getPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func hasPassword() -> Bool {
        guard let pass = getPassword() else { return false }
        return !pass.isEmpty
    }

    public static func deletePassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Hardware Keystroke Injection to Lock Screen (Glance-Engineered)

    public static func unlockLockScreen(password: String) {
        do {
            try KeystrokeInjector.typePassword(password)
        } catch {
            print("[KeychainHelper] Keystroke injection error: \(error.localizedDescription)")
        }
    }
}

