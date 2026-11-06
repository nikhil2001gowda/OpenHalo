//
//  GlanceFaceDetector.swift
//  Glance Engine for OpenHalo
//
//  Directly from jonnyoo/glance: Converts Vision's normalized (0...1), bottom-left-origin
//  face boxes into pixel-space, top-left-origin CGRects. Chained quality and landmark requests.
//

import Vision
import CoreGraphics

public struct GlanceDetectedFace: Sendable {
    /// Pixel-space bounding box, top-left origin — ready to crop with.
    public let boundingBox: CGRect
    /// Vision's original normalized box
    public let normalizedBoundingBox: CGRect
    /// 0...1 confidence from Vision that this is a face
    public let quality: Float?
    /// Head rotation in radians
    public let yaw: Float?
    public let roll: Float?
    public let pitch: Float?
    /// Facial landmarks
    public nonisolated let landmarks: VNFaceLandmarks2D?
    public let imageSize: CGSize
}

public nonisolated enum GlanceFaceDetector {
    /// Runs face-rectangle, capture-quality, and landmarks detection on a single frame.
    public static func detectFaces(in image: CGImage) throws -> [GlanceDetectedFace] {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        let rectanglesRequest = VNDetectFaceRectanglesRequest()
        try handler.perform([rectanglesRequest])
        let faceObservations = rectanglesRequest.results ?? []
        guard !faceObservations.isEmpty else { return [] }

        // Chained to rectangles results (via inputFaceObservations) rather than run independently
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
            return GlanceDetectedFace(
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

    /// Vision's normalized rect has origin at bottom-left; CGImage.cropping expects top-left.
    public static func convertToImageSpace(_ normalizedRect: CGRect, imageSize: CGSize) -> CGRect {
        let x = normalizedRect.origin.x * imageSize.width
        let width = normalizedRect.width * imageSize.width
        let height = normalizedRect.height * imageSize.height
        let y = (1 - normalizedRect.origin.y) * imageSize.height - height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Crops face out of image with padding
    public static func crop(_ face: GlanceDetectedFace, from image: CGImage, paddingFraction: CGFloat = 0.2) -> CGImage? {
        let imageBounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let padX = face.boundingBox.width * paddingFraction
        let padY = face.boundingBox.height * paddingFraction
        let padded = face.boundingBox.insetBy(dx: -padX, dy: -padY).intersection(imageBounds)
        guard !padded.isEmpty else { return nil }
        return image.cropping(to: padded)
    }
}
