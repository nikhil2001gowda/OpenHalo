import Foundation

public enum SIPSImageFormat: String, CaseIterable, Identifiable, Sendable {
    case png = "png"
    case jpeg = "jpeg"
    case webp = "webp"
    case heic = "heic"
    case tiff = "tiff"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        case .heic: return "HEIC"
        case .tiff: return "TIFF"
        }
    }
}

public enum SIPSOperationError: LocalizedError, Sendable {
    case executionFailed(String)
    case fileNotFound
    case unsupportedOperation

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let msg): return "SIPS conversion error: \(msg)"
        case .fileNotFound: return "Target file does not exist on disk."
        case .unsupportedOperation: return "Operation unsupported for this file type."
        }
    }
}

public actor SIPSConversionService {
    public static let shared = SIPSConversionService()

    private let sipsPath = "/usr/bin/sips"

    public init() {}

    /// Converts an input image to the target format.
    /// Returns the URL of the newly created image file.
    public func convert(inputURL: URL, to format: SIPSImageFormat, outputDirectory: URL? = nil) throws -> URL {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw SIPSOperationError.fileNotFound
        }

        let dir = outputDirectory ?? inputURL.deletingLastPathComponent()
        let originalName = inputURL.deletingPathExtension().lastPathComponent
        let targetURL = dir.appendingPathComponent("\(originalName).\(format.rawValue)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: sipsPath)
        process.arguments = ["-s", "format", format.rawValue, inputURL.path, "--out", targetURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? "Non-zero exit code"
            throw SIPSOperationError.executionFailed(errorText)
        }

        return targetURL
    }

    /// Resizes image by setting maximum dimension (width or height) to maxDimension pixels.
    public func downscale(inputURL: URL, maxDimension: Int, outputDirectory: URL? = nil) throws -> URL {
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw SIPSOperationError.fileNotFound
        }

        let dir = outputDirectory ?? inputURL.deletingLastPathComponent()
        let originalName = inputURL.deletingPathExtension().lastPathComponent
        let ext = inputURL.pathExtension
        let targetURL = dir.appendingPathComponent("\(originalName)_\(maxDimension)px.\(ext)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: sipsPath)
        process.arguments = ["-Z", "\(maxDimension)", inputURL.path, "--out", targetURL.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? "Non-zero exit code"
            throw SIPSOperationError.executionFailed(errorText)
        }

        return targetURL
    }
}
