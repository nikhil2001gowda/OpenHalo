import Foundation
import AppKit

public enum SoundEffectManager {
    public static func playChime() {
        NSSound(named: "Glass")?.play()
    }

    public static func playTimerDone() {
        NSSound(named: "Blow")?.play()
    }

    public static func playDropStash() {
        NSSound(named: "Pop")?.play()
    }

    public static func playActionBeep() {
        NSSound(named: "Tink")?.play()
    }
}

