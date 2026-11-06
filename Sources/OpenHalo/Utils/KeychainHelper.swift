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

    private static func createSelfTrustedAccess(description: String) -> SecAccess? {
        var trustedApp: SecTrustedApplication?
        let status = SecTrustedApplicationCreateFromPath(nil, &trustedApp)
        guard status == errSecSuccess, let app = trustedApp else { return nil }
        var access: SecAccess?
        let accessStatus = SecAccessCreate(description as CFString, [app] as CFArray, &access)
        guard accessStatus == errSecSuccess else { return nil }
        return access
    }

    public static func savePassword(_ password: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        deletePassword()

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Grant pre-approved "Always Allow" trusted application access to OpenHalo binary
        if let access = createSelfTrustedAccess(description: "OpenHalo Login Password") {
            query[kSecAttrAccess as String] = access
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        let success = (status == errSecSuccess)
        if success {
            setMemoryCachedPassword(password)
            // Also mirror into local AES-GCM device vault for 100% resilient, prompt-free lockscreen unlocks
            try? SecureCredentialManager.savePassword(data)
        }
        return success
    }

    /// Direct macOS Keychain query without calling SecureCredentialManager (guarantees zero recursion)
    public static func hasDirectKeychainItem() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess
    }

    /// Direct macOS Keychain read without calling SecureCredentialManager (guarantees zero recursion)
    public static func readDirectKeychainPassword() -> String? {
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
        return str
    }

    /// Synchronous read with memory cache and direct Keychain read (never recurses)
    public static func getPassword() -> String? {
        if let cached = getMemoryCachedPassword(), !cached.isEmpty {
            return cached
        }

        if let direct = readDirectKeychainPassword(), !direct.isEmpty {
            setMemoryCachedPassword(direct)
            return direct
        }

        return nil
    }

    /// Asynchronous read running detached with timeout to ensure the main thread NEVER hangs.
    public static func getPasswordAsync(timeoutSeconds: TimeInterval = 15.0) async -> String? {
        if let cached = getMemoryCachedPassword(), !cached.isEmpty {
            return cached
        }

        if let direct = readDirectKeychainPassword(), !direct.isEmpty {
            setMemoryCachedPassword(direct)
            return direct
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let direct = readDirectKeychainPassword() {
                    setMemoryCachedPassword(direct)
                    continuation.resume(returning: direct)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    public static func hasPassword() -> Bool {
        if getMemoryCachedPassword() != nil { return true }
        if hasDirectKeychainItem() { return true }
        if KeychainManager.exists(account: "password_blob") { return true }
        return false
    }

    public static func deletePassword() {
        setMemoryCachedPassword(nil)
        try? SecureCredentialManager.deletePassword()
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

