//
//  GlanceFaceEmbedder.swift
//  Glance Engine for OpenHalo
//
//  Directly from jonnyoo/glance: Generates 2048-dimensional feature-print vectors
//  using Apple's native Vision framework and computes exact cosine similarity.
//

import Vision
import CoreGraphics

public enum GlanceFaceEmbedderError: LocalizedError {
    case noObservation
    case unsupportedElementType

    public var errorDescription: String? {
        switch self {
        case .noObservation:
            return "Vision did not produce a feature print for this image."
        case .unsupportedElementType:
            return "Feature print used an unexpected element type."
        }
    }
}

public nonisolated enum GlanceFaceEmbedding {
    /// Scales vector to unit length
    public static func l2Normalized(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(Float(0)) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }

    /// Cosine similarity, range -1...1 (higher = more similar match)
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }

    /// Generates Vision Feature Print vector for a given face crop
    public static func generateEmbedding(for faceImage: CGImage) throws -> [Float] {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: faceImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw GlanceFaceEmbedderError.noObservation
        }
        let count = observation.elementCount
        switch observation.elementType {
        case .float:
            var result = [Float](repeating: 0, count: count)
            observation.data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                let buffer = raw.bindMemory(to: Float.self)
                for i in 0..<count { result[i] = buffer[i] }
            }
            return l2Normalized(result)
        case .double:
            var result = [Float](repeating: 0, count: count)
            observation.data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                let buffer = raw.bindMemory(to: Double.self)
                for i in 0..<count { result[i] = Float(buffer[i]) }
            }
            return l2Normalized(result)
        default:
            throw GlanceFaceEmbedderError.unsupportedElementType
        }
    }
}
