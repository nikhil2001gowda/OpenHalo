//
//  GlancePreviewView.swift
//  Glance Engine for OpenHalo
//
//  Directly from jonnyoo/glance: Smooth, mirrored camera preview that correctly
//  calculates bounds + position rather than .frame to prevent CALayer distortion.
//

import SwiftUI
import AVFoundation
import AppKit

public struct GlancePreviewView: NSViewRepresentable {
    public let session: AVCaptureSession
    public var faces: [GlanceDetectedFace] = []

    public init(session: AVCaptureSession, faces: [GlanceDetectedFace] = []) {
        self.session = session
        self.faces = faces
    }

    public func makeNSView(context: Context) -> GlancePreviewHostView {
        GlancePreviewHostView(session: session)
    }

    public func updateNSView(_ nsView: GlancePreviewHostView, context: Context) {
        nsView.updateFaceBoxes(faces)
    }
}

public final class GlancePreviewHostView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer
    private var boxLayers: [CAShapeLayer] = []

    public init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        previewLayer.videoGravity = .resizeAspectFill
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // bounds+position, not .frame — Core Animation mis-reports .frame once a non-identity transform is applied
        previewLayer.bounds = CGRect(origin: .zero, size: bounds.size)
        previewLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        // Mirror horizontally at the layer level
        previewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        CATransaction.commit()
    }

    public func updateFaceBoxes(_ faces: [GlanceDetectedFace]) {
        boxLayers.forEach { $0.removeFromSuperlayer() }
        boxLayers = faces.map { face in
            let rect = previewLayer.layerRectConverted(fromMetadataOutputRect: face.normalizedBoundingBox)
            let shape = CAShapeLayer()
            shape.path = CGPath(rect: rect, transform: nil)
            shape.strokeColor = NSColor.systemGreen.cgColor
            shape.fillColor = NSColor.clear.cgColor
            shape.lineWidth = 2
            previewLayer.addSublayer(shape)
            return shape
        }
    }
}
