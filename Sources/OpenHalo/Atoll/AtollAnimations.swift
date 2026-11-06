/*
 * Adapted from Atoll (DynamicIsland) by Ebullioscopic
 * Fluid Spring & Elastic Notch Animation Curves
 */

import SwiftUI

public enum AtollAnimationStyle {
    case notch
    case pill
}

public struct AtollAnimations {
    public static var notchSpring: Animation {
        if #available(macOS 14.0, *) {
            return .spring(.bouncy(duration: 0.42, extraBounce: 0.12))
        } else {
            return .timingCurve(0.16, 1, 0.3, 1, duration: 0.65)
        }
    }

    public static var pillSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.76, blendDuration: 0)
    }

    public static var smoothHover: Animation {
        .easeInOut(duration: 0.22)
    }

    public static var quickSnap: Animation {
        .spring(response: 0.26, dampingFraction: 0.82)
    }
}

