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

    // MARK: - Hardware Keystroke Injection to Lock Screen

    public static func unlockLockScreen(password: String) {
        // Send a tap to ensure password field is focused
        let spaceDown = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)
        spaceDown?.post(tap: .cghidEventTap)
        let spaceUp = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: false)
        spaceUp?.post(tap: .cghidEventTap)

        usleep(120000) // 120ms pause after wake tap

        // Type password characters via CGEvent hardware unicode injection
        for char in password {
            if let unichar = char.utf16.first {
                let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
                down?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unichar])
                down?.post(tap: .cghidEventTap)

                let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
                up?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [unichar])
                up?.post(tap: .cghidEventTap)
                usleep(10000) // 10ms between keystrokes
            }
        }

        // Submit password via Return key (keyCode 36)
        usleep(80000)
        let returnDown = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true)
        returnDown?.post(tap: .cghidEventTap)
        let returnUp = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false)
        returnUp?.post(tap: .cghidEventTap)
    }
}

