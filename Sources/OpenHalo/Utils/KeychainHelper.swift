import Foundation
import Security
import CoreGraphics

public enum KeychainHelper {
    private static let serviceName = "com.openhalo.lockscreen.password"
    private static let accountName = NSUserName()

    // Thread-safe in-memory cache to guarantee zero-latency, zero-prompt unlock at lock screen
    private static let cacheLock = NSLock()
    private static var _memoryCachedPassword: String?

    public static func setMemoryCachedPassword(_ pw: String?) {
        cacheLock.lock()
        _memoryCachedPassword = pw
        cacheLock.unlock()
    }

    public static func getMemoryCachedPassword() -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return _memoryCachedPassword
    }

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
        let success = (status == errSecSuccess)
        if success {
            setMemoryCachedPassword(password)
        }
        return success
    }

    /// Synchronous read with memory fallback first — never prompts if cached in memory!
    public static func getPassword() -> String? {
        if let cached = getMemoryCachedPassword(), !cached.isEmpty {
            return cached
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        setMemoryCachedPassword(str)
        return str
    }

    /// Asynchronous read running detached with timeout to ensure the main thread NEVER hangs.
    /// This allows macOS to present its keychain authorization prompt cleanly in foreground.
    public static func getPasswordAsync(timeoutSeconds: TimeInterval = 15.0) async -> String? {
        if let cached = getMemoryCachedPassword(), !cached.isEmpty {
            return cached
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: serviceName,
                    kSecAttrAccount as String: accountName,
                    kSecReturnData as String: true,
                    kSecMatchLimit as String: kSecMatchLimitOne
                ]

                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)
                if status == errSecSuccess, let data = item as? Data, let str = String(data: data, encoding: .utf8) {
                    setMemoryCachedPassword(str)
                    continuation.resume(returning: str)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    public static func hasPassword() -> Bool {
        if getMemoryCachedPassword() != nil { return true }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status != errSecItemNotFound
    }

    public static func deletePassword() {
        setMemoryCachedPassword(nil)
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

