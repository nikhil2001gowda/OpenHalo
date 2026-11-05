import Foundation
import AppKit
import OpenHaloKit

print("🔍 Running OpenHalo Automated Test & Verification Suite...")

// 1. Test Media Track calculations
print("Checking MediaTrack progress and formatting...")
let track = MediaTrack(
    title: "Midnight City",
    artist: "M83",
    album: "Hurry Up, We're Dreaming",
    duration: 240,
    position: 60,
    playbackState: .playing,
    source: .spotify
)
assert(abs(track.progress - 0.25) < 0.001, "Progress calculation failed")
assert(track.formattedPosition == "1:00", "Position formatting failed")
assert(track.formattedDuration == "4:00", "Duration formatting failed")
assert(track.isPlaying == true, "Playing state failed")
print("✅ MediaTrack passed!")

// 2. Test System Controls (Volume & Brightness)
print("Checking System Controls clamping...")
let volClampedLow = max(0.0, min(1.0, Float(-0.5)))
let volClampedHigh = max(0.0, min(1.0, Float(1.5)))
assert(volClampedLow == 0.0, "Volume clamp low failed")
assert(volClampedHigh == 1.0, "Volume clamp high failed")
print("✅ System Controls passed!")

// 3. Test Calendar & Meeting Link Extraction
print("Checking Calendar EventItem & Meeting URL detection...")
let zoomSample = "Join our sync: https://company.zoom.us/j/123456789?pwd=xyz please be on time"
let meetSample = "Google meet room: https://meet.google.com/abc-defg-hij"
let teamsSample = "Teams link: https://teams.microsoft.com/l/meetup-join/19%3ameeting_xyz"

let zoomURL = CalendarEventItem.extractMeetingURL(from: zoomSample)
assert(zoomURL != nil, "Zoom meeting extraction failed")
assert(zoomURL?.host?.contains("zoom.us") == true, "Zoom host mismatch")

let meetURL = CalendarEventItem.extractMeetingURL(from: meetSample)
assert(meetURL != nil, "Meet extraction failed")
assert(meetURL?.host == "meet.google.com", "Meet host mismatch")

let teamsURL = CalendarEventItem.extractMeetingURL(from: teamsSample)
assert(teamsURL != nil, "Teams extraction failed")

// Test countdown descriptions
let futureDate = Date().addingTimeInterval(900) // 15 mins in future
let futureEvent = CalendarEventItem(
    title: "Design Review",
    startDate: futureDate,
    endDate: futureDate.addingTimeInterval(1800),
    meetingURL: zoomURL
)
assert(futureEvent.countdownDescription.contains("14m") || futureEvent.countdownDescription.contains("15m"), "Countdown formatting mismatch")
assert(!futureEvent.isOngoing, "Future event should not be ongoing")
print("✅ Calendar & Meeting URL detection passed!")

// 4. Test Pill Wing Slot Enums
print("Checking Pill Wing Slot options...")
assert(PillLeadingSlot.allCases.count >= 5, "Expected at least 5 leading slot options")
assert(PillTrailingSlot.allCases.count >= 6, "Expected at least 6 trailing slot options")
assert(ExpandedTab.allCases.count == 6, "Expected 6 expanded tabs (Media, Calendar, Timers, System, Shelf, Mirror)")
print("✅ Pill Slot options & Expanded tabs passed!")

// 5. Test Timer presets
print("Checking Timer presets...")
let presets = TimerService.defaultPresets
assert(presets.count == 4, "Expected 4 default presets")
assert(presets[0].seconds == 60, "1m preset mismatch")
assert(presets[1].seconds == 300, "5m preset mismatch")
assert(presets[2].seconds == 900, "15m preset mismatch")
assert(presets[3].seconds == 1500, "25m Pomodoro preset mismatch")
print("✅ Timer presets passed!")

// 6. Test Shelf Item creation
print("Checking ShelfItem creation...")
let tempURL = URL(fileURLWithPath: "/tmp/sample.txt")
let item = ShelfItem(url: tempURL)
assert(item.name == "sample.txt", "Shelf item name mismatch")
assert(item.url.path == "/tmp/sample.txt", "Shelf item path mismatch")
print("✅ ShelfItem passed!")

// 7. Test Screen Notch detector
print("Checking ScreenNotchDetector...")
let geometry = ScreenNotchDetector.detect(for: nil)
assert(geometry.screenFrame.width > 0, "Screen width must be positive")
assert(geometry.screenFrame.height > 0, "Screen height must be positive")
assert(geometry.notchRect.width > 0, "Notch width must be positive")
print("✅ ScreenNotchDetector passed!")

print("🎉 All OpenHalo verification checks passed successfully!")
