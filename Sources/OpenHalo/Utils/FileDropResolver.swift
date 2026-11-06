import Foundation
import AppKit
import UniformTypeIdentifiers

public enum FileDropResolver {
    /// Extracts file URLs directly from an AppKit dragging pasteboard (100% reliable)
    public static func resolveURLs(from pasteboard: NSPasteboard) -> [URL] {
        var results: [URL] = []

        func addURL(_ candidate: URL) {
            let standardized = candidate.standardizedFileURL
            let path = standardized.path
            // Check if file exists or if it is a valid file URL
            if FileManager.default.fileExists(atPath: path) || FileManager.default.fileExists(atPath: candidate.path) || candidate.isFileURL {
                if !results.contains(where: { $0.path == path || $0.path == candidate.path }) {
                    results.append(standardized)
                }
            }
        }

        func addPathString(_ str: String) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return }
            if let u = URL(string: trimmed), u.isFileURL {
                addURL(u)
            } else if trimmed.hasPrefix("file://") {
                if let u = URL(string: trimmed) {
                    addURL(u)
                }
            } else if trimmed.hasPrefix("/") {
                addURL(URL(fileURLWithPath: trimmed))
            }
        }

        // 1. Read NSURL objects directly (handles both [NSURL] and [URL] bridging)
        if let nsURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL] {
            for nsURL in nsURLs {
                addURL(nsURL as URL)
            }
        }
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for u in fileURLs {
                addURL(u)
            }
        }

        // 2. Read filenames from property list (classic Finder drag format)
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let filenames = pasteboard.propertyList(forType: filenamesType) as? [String] {
            for path in filenames {
                addPathString(path)
            }
        }

        // 3. Inspect all pasteboardItems
        if let items = pasteboard.pasteboardItems {
            for item in items {
                for type in [
                    NSPasteboard.PasteboardType.fileURL,
                    NSPasteboard.PasteboardType("public.file-url"),
                    NSPasteboard.PasteboardType("com.apple.finder.node"),
                    NSPasteboard.PasteboardType("NSFilenamesPboardType"),
                    NSPasteboard.PasteboardType.string
                ] {
                    if let stringVal = item.string(forType: type) {
                        addPathString(stringVal)
                    }
                    if let dataVal = item.data(forType: type) {
                        if let u = URL(dataRepresentation: dataVal, relativeTo: nil) {
                            addURL(u)
                        } else if let str = String(data: dataVal, encoding: .utf8) {
                            addPathString(str)
                        }
                    }
                }
            }
        }

        // 4. Raw string representation (lines of file paths or file URLs)
        if let string = pasteboard.string(forType: .string) {
            for line in string.components(separatedBy: .newlines) {
                addPathString(line)
            }
        }

        return results
    }

    /// Asynchronously extracts file URLs from an array of NSItemProvider instances (SwiftUI onDrop)
    public static func resolveURLs(from providers: [NSItemProvider]) async -> [URL] {
        var results: [URL] = []

        for provider in providers {
            if let url = await resolveSingleURL(from: provider) {
                let standardized = url.standardizedFileURL
                if !results.contains(where: { $0.path == standardized.path || $0.path == url.path }) {
                    results.append(standardized)
                }
            }
        }

        return results
    }

    private static func resolveSingleURL(from provider: NSItemProvider) async -> URL? {
        // 1. Load object using NSURL.self (conforms to NSItemProviderReading in Objective-C runtime)
        if provider.canLoadObject(ofClass: NSURL.self) {
            let loaded: URL? = await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: NSURL.self) { nsURL, _ in
                    if let ns = nsURL as? NSURL {
                        continuation.resume(returning: ns as URL)
                    } else if let u = nsURL as? URL {
                        continuation.resume(returning: u)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            if let url = loaded {
                return url
            }
        }

        // 2. Load item for conforming file UTIs
        let typesToTry = [
            UTType.fileURL.identifier,
            "public.file-url",
            UTType.item.identifier,
            UTType.content.identifier,
            UTType.data.identifier
        ]

        for typeIdentifier in typesToTry where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            let loaded: URL? = await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                    if let ns = item as? NSURL {
                        continuation.resume(returning: ns as URL)
                        return
                    }
                    if let url = item as? URL {
                        continuation.resume(returning: url)
                        return
                    }
                    if let data = item as? Data {
                        if let u = URL(dataRepresentation: data, relativeTo: nil) {
                            continuation.resume(returning: u)
                            return
                        }
                        if let str = String(data: data, encoding: .utf8) {
                            let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let u = URL(string: clean), u.isFileURL {
                                continuation.resume(returning: u)
                                return
                            }
                            if clean.hasPrefix("/") {
                                continuation.resume(returning: URL(fileURLWithPath: clean))
                                return
                            }
                        }
                    }
                    if let str = item as? String {
                        let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let u = URL(string: clean), u.isFileURL {
                            continuation.resume(returning: u)
                            return
                        }
                        if clean.hasPrefix("/") {
                            continuation.resume(returning: URL(fileURLWithPath: clean))
                            return
                        }
                    }
                    continuation.resume(returning: nil)
                }
            }
            if let url = loaded {
                return url
            }
        }

        return nil
    }
}
