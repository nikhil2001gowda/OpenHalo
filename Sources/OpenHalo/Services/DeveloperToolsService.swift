import Foundation
import CryptoKit

public enum DeveloperToolsService {
    public static func formatJSON(_ input: String) -> String {
        guard let data = input.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
              let formatted = String(data: prettyData, encoding: .utf8) else {
            return "Invalid JSON"
        }
        return formatted
    }

    public static func base64Encode(_ input: String) -> String {
        return Data(input.utf8).base64EncodedString()
    }

    public static func base64Decode(_ input: String) -> String {
        guard let data = Data(base64Encoded: input.trimmingCharacters(in: .whitespacesAndNewlines)),
              let decoded = String(data: data, encoding: .utf8) else {
            return "Invalid Base64"
        }
        return decoded
    }

    public static func generateUUID() -> String {
        return UUID().uuidString.lowercased()
    }

    public static func sha256(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
