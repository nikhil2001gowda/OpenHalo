import Foundation

public enum AppleScriptRunner {
    @discardableResult
    public static func run(_ script: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    let output = appleScript.executeAndReturnError(&error)
                    if error != nil {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: output.stringValue)
                    }
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

