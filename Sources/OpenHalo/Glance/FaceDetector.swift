//
//  FaceDetector.swift
//  glance
//
//  Converts Vision's normalized (0...1), bottom-left-origin face boxes into pixel-space, top-left-origin `CGRect`s.
//

import Vision
import CoreGraphics
import CoreImage

struct DetectedFace {
    /// Pixel-space bounding box, top-left origin — ready to crop with.
    let boundingBox: CGRect
    /// Vision's original normalized box — kept as-is since it's the exact format `layerRectConverted(fromMetadataOutputRect:)` expects.
    let normalizedBoundingBox: CGRect
    /// 0...1 confidence from Vision that this is a face, roughly indicating
    /// image quality/pose suitability for recognition. `nil` if the quality
    /// request didn't produce a result for this face.
    let quality: Float?
    /// Head rotation in radians, when Vision could estimate it. Yaw drives the guided-pose onboarding capture;
    /// roll and pitch are exposed but unused today.
    let yaw: Float?
    let roll: Float?
    let pitch: Float?
    /// Facial landmarks (eyes, nose, mouth, etc.), when available. Feeds
    /// `FaceAligner` for canonical 112x112 alignment ahead of ArcFace.
    nonisolated let landmarks: VNFaceLandmarks2D?
    /// Needed by `landmarks.pointsInImage(_:)` to convert normalized landmark points into `boundingBox`'s pixel space.
    let imageSize: CGSize
}

/// Pure, synchronous, CPU-bound work — `nonisolated` so it can run on a
/// background task despite the project's default main-actor isolation.
nonisolated enum FaceDetector {
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Runs face-rectangle, capture-quality, and landmarks detection on a single frame.
    /// Incorporates low-light / dark-night adaptive enhancement if primary detection finds no candidate.
    static func detectFaces(in image: CGImage) throws -> [DetectedFace] {
        let faces = try performDetection(on: image)
        if !faces.isEmpty {
            return faces
        }

        // Low-light / dark room retry: Enhance exposure and contrast using Core Image
        if let enhanced = enhanceLowLight(image) {
            let enhancedFaces = try performDetection(on: enhanced)
            if !enhancedFaces.isEmpty {
                return enhancedFaces
            }
        }

        return []
    }

    private static func enhanceLowLight(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)

        // 1. Exposure compensation (+1.6 EV)
        guard let exposureFilter = CIFilter(name: "CIExposureAdjust") else { return nil }
        exposureFilter.setValue(ciImage, forKey: kCIInputImageKey)
        exposureFilter.setValue(1.6, forKey: kCIInputEVKey)
        guard let exposed = exposureFilter.outputImage else { return nil }

        // 2. Color controls (boost contrast and brightness slightly)
        guard let colorFilter = CIFilter(name: "CIColorControls") else { return nil }
        colorFilter.setValue(exposed, forKey: kCIInputImageKey)
        colorFilter.setValue(1.25, forKey: kCIInputContrastKey)
        colorFilter.setValue(0.12, forKey: kCIInputBrightnessKey)
        guard let output = colorFilter.outputImage else { return nil }

        return ciContext.createCGImage(output, from: output.extent)
    }

    private static func performDetection(on image: CGImage) throws -> [DetectedFace] {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        let rectanglesRequest = VNDetectFaceRectanglesRequest()
        if #available(macOS 14.0, *) {
            rectanglesRequest.revision = VNDetectFaceRectanglesRequestRevision3
        }
        try handler.perform([rectanglesRequest])
        let faceObservations = rectanglesRequest.results ?? []
        guard !faceObservations.isEmpty else { return [] }

        // Chained to the rectangles results (via `inputFaceObservations`) rather than run independently, so results
        // correspond 1:1 in order — avoids the fragility of matching back via boundingBox float equality.
        let qualityRequest = VNDetectFaceCaptureQualityRequest()
        let landmarksRequest = VNDetectFaceLandmarksRequest()
        qualityRequest.inputFaceObservations = faceObservations
        landmarksRequest.inputFaceObservations = faceObservations
        try handler.perform([qualityRequest, landmarksRequest])

        let qualityResults = qualityRequest.results ?? []
        let landmarkResults = landmarksRequest.results ?? []
        let imageSize = CGSize(width: image.width, height: image.height)

        return faceObservations.enumerated().map { index, observation in
            let pixelRect = convertToImageSpace(observation.boundingBox, imageSize: imageSize)
            return DetectedFace(
                boundingBox: pixelRect,
                normalizedBoundingBox: observation.boundingBox,
                quality: qualityResults.indices.contains(index) ? qualityResults[index].faceCaptureQuality : nil,
                yaw: observation.yaw?.floatValue,
                roll: observation.roll?.floatValue,
                pitch: observation.pitch?.floatValue,
                landmarks: landmarkResults.indices.contains(index) ? landmarkResults[index].landmarks : nil,
                imageSize: imageSize
            )
        }
    }

    /// Vision's normalized rect has origin at bottom-left; `CGImage.cropping`
    /// expects pixel coordinates with origin at top-left. This flips the Y axis.
    static func convertToImageSpace(_ normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
        let x = normalizedRect.origin.x * imageSize.width
        let width = normalizedRect.width * imageSize.width
        let height = normalizedRect.height * imageSize.height
        let y = (1 - normalizedRect.origin.y) * imageSize.height - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Crops `face` out of `image`, padding slightly around the detected box
    /// so the embedder sees a bit of context beyond just eyes/nose/mouth.
    static func crop(_ face: DetectedFace, from image: CGImage, paddingFraction: CGFloat = 0.2) -> CGImage? {
        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let padX = face.boundingBox.width * paddingFraction
        let padY = face.boundingBox.height * paddingFraction
        let padded = face.boundingBox.insetBy(dx: -padX, dy: -padY).intersection(imageBounds)
        guard !padded.isEmpty else { return nil }
        return image.cropping(to: padded)
    }
}
