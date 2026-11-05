import Foundation
import AppKit

public struct DisplayGeometry: Equatable, Sendable {
    public let hasNotch: Bool
    public let notchRect: CGRect
    public let screenFrame: CGRect
    public let topMargin: CGFloat

    public init(
        hasNotch: Bool,
        notchRect: CGRect,
        screenFrame: CGRect,
        topMargin: CGFloat = 0
    ) {
        self.hasNotch = hasNotch
        self.notchRect = notchRect
        self.screenFrame = screenFrame
        self.topMargin = topMargin
    }
}

public enum ScreenNotchDetector {
    public static func detect(for screen: NSScreen? = NSScreen.main) -> DisplayGeometry {
        guard let screen = screen ?? NSScreen.screens.first else {
            let defaultFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
            return DisplayGeometry(
                hasNotch: false,
                notchRect: CGRect(x: 625, y: 860, width: 190, height: 36),
                screenFrame: defaultFrame,
                topMargin: 8
            )
        }

        let frame = screen.frame
        let safeArea = screen.safeAreaInsets

        // Check for MacBook display notch
        if safeArea.top > 0,
           let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea,
           rightArea.minX > leftArea.maxX {

            let notchWidth = rightArea.minX - leftArea.maxX
            let notchHeight = safeArea.top // Exactly 32.0 on modern notched MacBooks
            let notchOriginX = leftArea.maxX
            let notchOriginY = frame.height - safeArea.top

            let notchRect = CGRect(x: notchOriginX, y: notchOriginY, width: notchWidth, height: notchHeight)
            return DisplayGeometry(
                hasNotch: true,
                notchRect: notchRect,
                screenFrame: frame,
                topMargin: 0
            )
        } else {
            // Floating Pill for external displays or notchless MacBooks
            let pillWidth: CGFloat = 190.0
            let pillHeight: CGFloat = 36.0
            let margin: CGFloat = 8.0
            let pillRect = CGRect(
                x: frame.midX - (pillWidth / 2.0),
                y: frame.maxY - pillHeight - margin,
                width: pillWidth,
                height: pillHeight
            )
            return DisplayGeometry(
                hasNotch: false,
                notchRect: pillRect,
                screenFrame: frame,
                topMargin: margin
            )
        }
    }
}

