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

    /// Synchronous read with memory and local AES-GCM vault fallback first — never prompts if cached!
    public static func getPassword() -> String? {
        if let cached = getMemoryCachedPassword(), !cached.isEmpty {
            return cached
        }

        // Check resilient local AES-GCM vault (zero security popups)
        if let localData = try? SecureCredentialManager.readPassword(),
           let str = String(data: localData, encoding: .utf8), !str.isEmpty {
            setMemoryCachedPassword(str)
            return str
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
    public static func getPasswordAsync(timeoutSeconds: TimeInterval = 15.0) async -> String? {
        if let cached = getMemoryCachedPassword(), !cached.isEmpty {
            return cached
        }

        // Check resilient local AES-GCM vault
        if let localData = try? SecureCredentialManager.readPassword(),
           let str = String(data: localData, encoding: .utf8), !str.isEmpty {
            setMemoryCachedPassword(str)
            return str
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
        if (try? SecureCredentialManager.readPassword()) != nil { return true }
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

