/*
 * Adapted from Atoll (DynamicIsland) by Ebullioscopic
 * Notch Dropping Shape: Flush against the top display bezel with rounded bottom corners
 */

import SwiftUI

/// A shape whose top corners are flush with the top screen bezel (radius 0)
/// and whose bottom corners are gracefully rounded, creating the authentic
/// physical drop-down appearance of the MacBook notch.
public struct AtollBottomRoundedRectangle: InsettableShape {
    public var radius: CGFloat
    public var insetAmount: CGFloat = 0

    public init(radius: CGFloat = 24) {
        self.radius = radius
        self.insetAmount = 0
    }

    public var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }

    public func inset(by amount: CGFloat) -> AtollBottomRoundedRectangle {
        var copy = self
        copy.insetAmount += amount
        return copy
    }

    public func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let effectiveRadius = max(0, radius - insetAmount)
        var path = Path()

        // Top left corner (flush against screen top bezel)
        path.move(to: CGPoint(x: insetRect.minX, y: insetRect.minY))

        // Top right corner (flush against screen top bezel)
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.minY))

        // Bottom right corner (rounded)
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - effectiveRadius))
        path.addArc(
            center: CGPoint(x: insetRect.maxX - effectiveRadius, y: insetRect.maxY - effectiveRadius),
            radius: effectiveRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )

        // Bottom left corner (rounded)
        path.addLine(to: CGPoint(x: insetRect.minX + effectiveRadius, y: insetRect.maxY))
        path.addArc(
            center: CGPoint(x: insetRect.minX + effectiveRadius, y: insetRect.maxY - effectiveRadius),
            radius: effectiveRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}
