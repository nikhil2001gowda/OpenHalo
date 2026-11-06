import Foundation

public enum ZipArchiveError: LocalizedError, Sendable {
    case executionFailed(String)
    case noFilesProvided
    case targetCreationFailed

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return "Archive error: \(msg)"
        case .noFilesProvided: return "No files were selected to archive."
        case .targetCreationFailed: return "Unable to create target archive file."
        }
    }
}

public actor ZipArchiveService {
    public static let shared = ZipArchiveService()

    private let dittoPath = "/usr/bin/ditto"

    public init() {}

    /// Archives one or more URLs into a Finder-compatible .zip file.
    /// Preserves macOS extended attributes, permissions, and resource forks.
    public func createZip(from urls: [URL], outputName: String? = nil, outputDirectory: URL? = nil) throws -> URL {
        guard !urls.isEmpty else {
            throw ZipArchiveError.noFilesProvided
        }

        let firstURL = urls[0]
        let baseDir = outputDirectory ?? firstURL.deletingLastPathComponent()
        let archiveBaseName: String
        if let outputName = outputName, !outputName.isEmpty {
            archiveBaseName = outputName.replacingOccurrences(of: ".zip", with: "")
        } else if urls.count == 1 {
            archiveBaseName = "\(urls[0].deletingPathExtension().lastPathComponent)-archive"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            archiveBaseName = "Archive-\(formatter.string(from: Date()))"
        }

        let targetZipURL = baseDir.appendingPathComponent("\(archiveBaseName).zip")

        if urls.count == 1 {
            // Single file or directory
            let singleURL = urls[0]
            let process = Process()
            process.executableURL = URL(fileURLWithPath: dittoPath)
            process.arguments = ["-c", "-k", "--sequesterRsrc", singleURL.path, targetZipURL.path]

            let errorPipe = Pipe()
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8) ?? "Non-zero exit code"
                throw ZipArchiveError.executionFailed(errorText)
            }

            return targetZipURL
        } else {
            // Multiple files: stage in a temporary folder so ditto archives all of them cleanly
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("OpenHaloArchive-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }

            for url in urls {
                let dest = tempDir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: url, to: dest)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: dittoPath)
            process.arguments = ["-c", "-k", "--sequesterRsrc", tempDir.path, targetZipURL.path]

            let errorPipe = Pipe()
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8) ?? "Non-zero exit code"
                throw ZipArchiveError.executionFailed(errorText)
            }

            return targetZipURL
        }
    }
}
