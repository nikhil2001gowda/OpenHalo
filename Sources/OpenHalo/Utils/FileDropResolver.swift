import Foundation
import AppKit
import UniformTypeIdentifiers

public enum FileDropResolver {
    /// Extracts file URLs directly from an AppKit dragging pasteboard (100% reliable)
    public static func resolveURLs(from pasteboard: NSPasteboard) -> [URL] {
        var results: [URL] = []

        // 1. Try reading NSURL objects directly
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !fileURLs.isEmpty {
            for url in fileURLs {
                if FileManager.default.fileExists(atPath: url.path) && !results.contains(where: { $0.path == url.path }) {
                    results.append(url)
                }
            }
        }

        // 2. Try filenames property list (classic Finder drag format)
        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if let filenames = pasteboard.propertyList(forType: filenamesType) as? [String] {
            for path in filenames {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: url.path) && !results.contains(where: { $0.path == url.path }) {
                    results.append(url)
                }
            }
        }

        // 3. Try string representations (e.g. file:///... or /...)
        if let string = pasteboard.string(forType: .string) {
            let lines = string.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                if let url = URL(string: trimmed), url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
                    if !results.contains(where: { $0.path == url.path }) {
                        results.append(url)
                    }
                } else if trimmed.hasPrefix("/") && FileManager.default.fileExists(atPath: trimmed) {
                    let url = URL(fileURLWithPath: trimmed)
                    if !results.contains(where: { $0.path == url.path }) {
                        results.append(url)
                    }
                }
            }
        }

        return results
    }

    /// Asynchronously extracts file URLs from an array of NSItemProvider instances (SwiftUI onDrop)
    public static func resolveURLs(from providers: [NSItemProvider]) async -> [URL] {
        var results: [URL] = []

        for provider in providers {
            if let url = await resolveSingleURL(from: provider) {
                if !results.contains(where: { $0.path == url.path }) {
                    results.append(url)
                }
            }
        }

        return results
    }

    private static func resolveSingleURL(from provider: NSItemProvider) async -> URL? {
        // 1. Modern loadObject for URL
        if provider.canLoadObject(ofClass: URL.self) {
            let loaded: URL? = await withCheckedContinuation { continuation in
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    continuation.resume(returning: url)
                }
            }
            if let url = loaded, url.isFileURL && FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        // 2. Load item for UTType.fileURL
        let fileTypes = [UTType.fileURL.identifier, UTType.item.identifier, "public.file-url"]
        for typeIdentifier in fileTypes where provider.hasItemConformingToTypeIdentifier(typeIdentifier) {
            let loaded: URL? = await withCheckedContinuation { continuation in
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                    var candidate: URL? = nil
                    if let url = item as? URL {
                        candidate = url
                    } else if let data = item as? Data {
                        if let str = String(data: data, encoding: .utf8) {
                            let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                            if let u = URL(string: clean), u.isFileURL {
                                candidate = u
                            } else if clean.hasPrefix("/") {
                                candidate = URL(fileURLWithPath: clean)
                            }
                        }
                    } else if let str = item as? String {
                        let clean = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let u = URL(string: clean), u.isFileURL {
                            candidate = u
                        } else if clean.hasPrefix("/") {
                            candidate = URL(fileURLWithPath: clean)
                        }
                    }
                    continuation.resume(returning: candidate)
                }
            }
            if let url = loaded, FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
