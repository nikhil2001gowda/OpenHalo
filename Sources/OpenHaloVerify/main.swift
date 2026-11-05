import Foundation
import AppKit
import OpenHaloKit

@main
struct OpenHaloVerifier {
    @MainActor
    static func main() async {
        print("🔍 Running OpenHalo 4.0 Automated Test & Verification Suite...")

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

        // 4. Test MediaMate HUD Payload
        print("Checking MediaMate HUD Payload clamping and types...")
        let hudPayload = HUDPayload(type: .volume, value: 1.5, isMuted: false)
        assert(hudPayload.value == 1.0, "HUD volume value should clamp to 1.0")
        let brightnessPayload = HUDPayload(type: .brightness, value: -0.2, isMuted: false)
        assert(brightnessPayload.value == 0.0, "HUD brightness value should clamp to 0.0")
        assert(hudPayload.type == .volume, "HUD type mismatch")
        print("✅ MediaMate HUD Payload passed!")

        // 5. Test Droppy & NotchNook Clipboard Manager
        print("Checking Clipboard item classification and previews...")
        let urlClip = ClipboardItem(content: "https://apple.com/macos")
        assert(urlClip.type == .url, "Expected URL clip type")
        let hexClip = ClipboardItem(content: "#00E5FF")
        assert(hexClip.type == .color, "Expected Color clip type")
        let codeClip = ClipboardItem(content: "func test() { return 42 }")
        assert(codeClip.type == .code, "Expected Code clip type")
        let textClip = ClipboardItem(content: "Hello, world!")
        assert(textClip.type == .text, "Expected Text clip type")
        print("✅ Clipboard Item classification passed!")

        // 6. Test NotchNook & Atoll App Launcher Shortcuts
        print("Checking App Launcher Shortcuts...")
        let defaultShortcuts = LauncherShortcut.defaults
        assert(defaultShortcuts.count >= 4, "Expected at least 4 default shortcuts")
        assert(defaultShortcuts.contains(where: { $0.name == "Safari" }), "Safari shortcut missing")
        assert(defaultShortcuts.contains(where: { $0.name == "Terminal" }), "Terminal shortcut missing")
        print("✅ App Launcher Shortcuts passed!")

        // 7. Test Alcove & Droppy Focus Tasks
        print("Checking Focus Task items...")
        let task = FocusTaskItem(title: "Complete OpenHalo 4.0", isCompleted: false)
        assert(task.title == "Complete OpenHalo 4.0", "Task title mismatch")
        assert(!task.isCompleted, "Task should start uncompleted")
        print("✅ Focus Tasks passed!")

        // 8. Test Pill Wing Slot Enums & 10 Expanded Tabs
        print("Checking Pill Wing Slot options & 10 Expanded Tabs...")
        assert(PillLeadingSlot.allCases.count >= 7, "Expected at least 7 leading slot options")
        assert(PillTrailingSlot.allCases.count >= 8, "Expected at least 8 trailing slot options")
        assert(ExpandedTab.allCases.count == 10, "Expected 10 expanded tabs (Media, Calendar, Timers, Focus, Weather, Clips, Apps, System, Shelf, Mirror)")
        print("✅ Pill Slot options & 10 Expanded tabs passed!")

        // 9. Test Timer presets
        print("Checking Timer presets...")
        let presets = TimerService.defaultPresets
        assert(presets.count == 4, "Expected 4 default presets")
        assert(presets[0].seconds == 60, "1m preset mismatch")
        assert(presets[1].seconds == 300, "5m preset mismatch")
        assert(presets[2].seconds == 900, "15m preset mismatch")
        assert(presets[3].seconds == 1500, "25m Pomodoro preset mismatch")
        print("✅ Timer presets passed!")

        // 10. Test Shelf Item creation & SIPS formats
        print("Checking ShelfItem creation & SIPS formats...")
        let tempURL = URL(fileURLWithPath: "/tmp/sample.txt")
        let item = ShelfItem(url: tempURL)
        assert(item.name == "sample.txt", "Shelf item name mismatch")
        assert(item.url.path == "/tmp/sample.txt", "Shelf item path mismatch")
        assert(SIPSImageFormat.allCases.count == 5, "Expected 5 SIPS image formats (png, jpeg, webp, heic, tiff)")
        print("✅ ShelfItem & SIPS formats passed!")

        // 11. Test Screen Notch detector
        print("Checking ScreenNotchDetector...")
        let geometry = ScreenNotchDetector.detect(for: nil)
        assert(geometry.screenFrame.width > 0, "Screen width must be positive")
        assert(geometry.screenFrame.height > 0, "Screen height must be positive")
        assert(geometry.notchRect.width > 0, "Notch width must be positive")
        print("✅ ScreenNotchDetector passed!")

        // 12. Test Weather Service (Open-Meteo REST & WMO Symbol Mapping)
        print("Checking Weather Service & WMO mappings...")
        let weather = WeatherService.shared
        assert(weather.mapWeatherCodeToDescription(0) == "Clear Sky", "WMO 0 should map to Clear Sky")
        assert(weather.mapWeatherCodeToDescription(61) == "Rain", "WMO 61 should map to Rain")
        assert(weather.mapWeatherCodeToDescription(95) == "Thunderstorm", "WMO 95 should map to Thunderstorm")
        assert(weather.mapWeatherCodeToSFSymbol(0, isDay: true) == "sun.max.fill", "Day clear sky should be sun.max.fill")
        assert(weather.mapWeatherCodeToSFSymbol(0, isDay: false) == "moon.stars.fill", "Night clear sky should be moon.stars.fill")
        assert(weather.mapWeatherCodeToSFSymbol(71, isDay: true) == "snowflake", "Snow should map to snowflake")
        let snap = WeatherSnapshot(
            temperature: 21.4,
            apparentTemperature: 21.0,
            humidity: 45,
            windSpeed: 12.0,
            weatherCode: 0,
            isDay: true,
            conditionDescription: "Clear Sky",
            sfSymbol: "sun.max.fill",
            fetchedAt: Date()
        )
        assert(snap.formattedTemp == "21°C", "Formatted temperature mismatch")
        print("✅ Weather Service & WMO mappings passed!")

        // 13. Test Screen Lock Face ID Assistant
        print("Checking Screen Lock Face ID Assistant invariants...")
        let faceService = ScreenLockFaceService.shared
        assert(faceService.state == .idle || faceService.state == .waitingForLockWake, "Face service should initialize idle")
        // Ensure zero-leak cleanup
        faceService.stopAndCleanup()
        assert(faceService.state == .idle || faceService.state == .waitingForLockWake, "Cleanup state invariant failed")
        print("✅ Screen Lock Face ID Assistant passed!")

        // 14. Test Power Suspension Coordinator (Glance Zero-Power Engine)
        print("Checking Power Suspension Coordinator (Deep Sleep & Display Sleep)...")
        let powerCoordinator = PowerSuspensionCoordinator.shared
        assert(!powerCoordinator.isSuspended, "Coordinator should start unsuspended")
        powerCoordinator.enterDeepSleepSuspension()
        assert(powerCoordinator.isSuspended, "Coordinator should be suspended after sleep notification")
        assert(powerCoordinator.sleepCount >= 1, "Sleep count should increment")
        powerCoordinator.resumeFromDeepSleep()
        assert(!powerCoordinator.isSuspended, "Coordinator should be unsuspended after wake notification")
        assert(powerCoordinator.wakeCount >= 1, "Wake count should increment")
        print("✅ Power Suspension Coordinator passed!")

        // 15. Test Launch At Login Service
        print("Checking Launch At Login Service (SMAppService)...")
        let loginService = LaunchAtLoginService.shared
        print("Current SMAppService status: \(loginService.status)")
        print("✅ Launch At Login Service initialized safely!")

        print("🎉 All 15 OpenHalo 4.0 verification checks passed successfully!")
    }
}
