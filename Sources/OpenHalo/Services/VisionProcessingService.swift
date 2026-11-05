import Foundation
import AppKit
import Vision
import CoreImage

public enum VisionProcessingService {
    /// Extracts all text from an image file using Apple Vision on-device OCR
    public static func extractText(from imageURL: URL) async throws -> String {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "OpenHaloVision", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image for OCR"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                let fullText = recognizedStrings.joined(separator: "\n")
                continuation.resume(returning: fullText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Removes background from an image on-device using Vision person segmentation
    public static func removeBackground(from imageURL: URL) async throws -> URL {
        guard let inputImage = CIImage(contentsOf: imageURL) else {
            throw NSError(domain: "OpenHaloVision", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid image for background removal"])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGeneratePersonSegmentationRequest()
            request.qualityLevel = .accurate
            request.outputPixelFormat = kCVPixelFormatType_OneComponent8

            let handler = VNImageRequestHandler(ciImage: inputImage, options: [:])
            do {
                try handler.perform([request])

                guard let mask = request.results?.first else {
                    continuation.resume(throwing: NSError(domain: "OpenHaloVision", code: 3, userInfo: [NSLocalizedDescriptionKey: "No subject detected in image"]))
                    return
                }

                let maskPixelBuffer = mask.pixelBuffer
                let maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

                // Scale mask to original image size
                let scaleX = inputImage.extent.width / maskImage.extent.width
                let scaleY = inputImage.extent.height / maskImage.extent.height
                let scaledMask = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                // Blend with clear background
                guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
                    continuation.resume(throwing: NSError(domain: "OpenHaloVision", code: 4, userInfo: [NSLocalizedDescriptionKey: "CoreImage blend filter unavailable"]))
                    return
                }

                blendFilter.setValue(inputImage, forKey: kCIInputImageKey)
                blendFilter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
                blendFilter.setValue(scaledMask, forKey: kCIInputMaskImageKey)

                guard let outputCI = blendFilter.outputImage else {
                    continuation.resume(throwing: NSError(domain: "OpenHaloVision", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to composite transparent subject"]))
                    return
                }

                let context = CIContext(options: nil)
                guard let cgOutput = context.createCGImage(outputCI, from: inputImage.extent) else {
                    continuation.resume(throwing: NSError(domain: "OpenHaloVision", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to render transparent CGImage"]))
                    return
                }

                let outputRep = NSBitmapImageRep(cgImage: cgOutput)
                guard let pngData = outputRep.representation(using: .png, properties: [:]) else {
                    continuation.resume(throwing: NSError(domain: "OpenHaloVision", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to export PNG data"]))
                    return
                }

                let outputURL = imageURL.deletingPathExtension().appendingPathExtension("no-bg.png")
                try pngData.write(to: outputURL)
                continuation.resume(returning: outputURL)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
