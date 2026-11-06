import Foundation
import AppKit
import PDFKit

public enum PDFMergeError: LocalizedError, Sendable {
    case noValidItems
    case writeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noValidItems: return "No valid images or PDF documents were found to merge."
        case .writeFailed(let path): return "Failed to write merged PDF document to \(path)"
        }
    }
}

public actor PDFMergeService {
    public static let shared = PDFMergeService()

    public init() {}

    /// Combines multiple image files or existing PDF files into a single unified PDF document.
    public func combineToPDF(urls: [URL], outputName: String? = nil, outputDirectory: URL? = nil) throws -> URL {
        guard !urls.isEmpty else {
            throw PDFMergeError.noValidItems
        }

        let firstURL = urls[0]
        let baseDir = outputDirectory ?? firstURL.deletingLastPathComponent()
        let pdfBaseName: String
        if let outputName = outputName, !outputName.isEmpty {
            pdfBaseName = outputName.replacingOccurrences(of: ".pdf", with: "")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            pdfBaseName = "Combined-Document-\(formatter.string(from: Date()))"
        }

        let targetPDFURL = baseDir.appendingPathComponent("\(pdfBaseName).pdf")
        let pdfDocument = PDFDocument()
        var pageIndex = 0

        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" {
                if let existingDoc = PDFDocument(url: url) {
                    for i in 0..<existingDoc.pageCount {
                        if let page = existingDoc.page(at: i) {
                            pdfDocument.insert(page, at: pageIndex)
                            pageIndex += 1
                        }
                    }
                }
            } else if ["png", "jpg", "jpeg", "webp", "heic", "tiff", "bmp", "gif"].contains(ext) {
                if let image = NSImage(contentsOf: url) {
                    if let page = PDFPage(image: image) {
                        pdfDocument.insert(page, at: pageIndex)
                        pageIndex += 1
                    }
                }
            }
        }

        guard pageIndex > 0 else {
            throw PDFMergeError.noValidItems
        }

        guard pdfDocument.write(to: targetPDFURL) else {
            throw PDFMergeError.writeFailed(targetPDFURL.path)
        }

        return targetPDFURL
    }
}
