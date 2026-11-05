<div align="center">

# OpenHalo 🏝️✨
### The Ultimate Native Dynamic Island for macOS

**Fluid. Private. Powerful. 100% Free & Open Source Forever.**

[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B%20(Sonoma%20%7C%20Sequoia)-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/nikhil2001gowda/OpenHalo)
[![Swift](https://img.shields.io/badge/Swift-6.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Zero Dependencies](https://img.shields.io/badge/Dependencies-0%20(100%25%20Native)-success?style=for-the-badge)](Package.swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)
[![Privacy First](https://img.shields.io/badge/Privacy-100%25%20Local%20%7C%20Zero%20Tracking-purple?style=for-the-badge)](docs/ARCHITECTURE.md)

<br/>

```
     ╭───────────────────────────────╮
     │  ♫ Midnight City   [==|===]   │   ← Idle Notch & Floating Pill
     ╰───────────────────────────────╯
                    ▼ (Hover or ⌘+⌃+I)
   ╭───────────────────────────────────────────╮
   │  [♫ Media] [🗓️ Meet] [⏱️ Timers] [📊 Sys] │
   │  ───────────────────────────────────────  │
   │  M83 — Hurry Up, We're Dreaming           │
   │  ⏮   ▶⏸   ⏭   ───●──── 🔊 [====|====]    │
   │                                           │
   │  🗓️ In 12m: Product Design Sync           │
   │  [ 🟢 Join Google Meet ]                   │
   ╰───────────────────────────────────────────╯
```

**OpenHalo** transforms the MacBook notch—and external displays—into an interactive, physics-driven command center. Seamlessly control your music, join upcoming meetings with one click, check your camera appearance before video calls, stash files for instant AirDrop, and monitor live system vitals.

**No subscriptions. No cloud accounts. No background telemetry. Pure native Swift.**

---

</div>

## 💡 Why OpenHalo?

Most Mac notch tools today charge expensive monthly subscriptions, bundle proprietary closed-source code, run heavy electron wrappers that eat your battery, or require invasive system permissions.

OpenHalo was engineered from the ground up to redefine what macOS utility software should be:

| Feature | OpenHalo (Free & Open Source) | Typical Paid Notch Apps |
| :--- | :---: | :---: |
| **Pricing** | **100% Free Forever (MIT)** | $15–$30 license or recurring sub |
| **Source Code** | **100% Open Source** | Closed-source proprietary |
| **Dependencies** | **0 (Pure Apple SDK)** | Multiple external frameworks / Electron |
| **Data Privacy** | **100% Local / Zero Outbound** | Cloud analytics / telemetry trackers |
| **Battery Impact** | **Near-Zero (Suspended at idle)** | Constant background polling |
| **Microphone Privacy** | **Zero-TCC HAL device listener** | Audio recording permissions / prompts |
| **Camera Mirror** | **Instant hardware cutoff** | Risk of persistent camera LED state |
| **Display Support** | **MacBook Notch + Floating Pill** | Often limited to built-in notch only |

---

## 🌟 Supercharged Feature Deck

### 1. 🏝️ Adaptive Notch & Floating Capsule Engine
- **Hardware Notch Snapping:** Automatically detects your MacBook Pro or MacBook Air display notch geometry using `NSScreen.safeAreaInsets` and docks flush to the bezel.
- **Universal Floating Island:** Running on an external display, Mac mini, Mac Studio, or notchless Mac? OpenHalo morphs into an elegant floating capsule pill with an 8pt margin from the menu bar.
- **Apple-Grade Spring Dynamics:** Interactive interactive spring morphing (`response: 0.35, dampingFraction: 0.75`) between idle capsule, hover peek, and full 6-tab expanded decks.

### 2. 🎛️ Customizable Pill Wing Slots (Left & Right)
Tailor the idle notch cap to show exactly what matters to you at a glance:
- **Left Wing Slot:**
  - `Smart Auto` (Prioritizes active timer → upcoming meeting → now playing music)
  - `Now Playing` (Track artist & title)
  - `Next Meeting` (Live countdown: *"In 14m"*)
  - `Pomodoro / Timer` (Live countdown clock)
  - `Digital Clock` (Current local time)
- **Right Wing Slot:**
  - `Smart Auto` (Prioritizes microphone security dot → audio waveform → battery)
  - `Audio Waveform` (Live animated sound equalizer bars)
  - `Battery Level` (Live battery % and charging glyph)
  - `Microphone Security Dot` (Active microphone indicator)
  - `Master Volume` (Live volume level indicator)
  - `Minimal` (Clean black notch bezel)

### 3. 🎵 Universal Media Center & Audio Controls
- **Apple Music & Spotify Support:** Automatically intercepts playback changes via low-overhead `DistributedNotificationCenter` listeners.
- **Full Interactive Deck:** Real-time album artwork, track title, artist name, and click-to-seek scrubber.
- **Built-in System Volume Slider:** Adjust master output audio directly inside the island using native CoreAudio HAL scalars.
- **Transport Controls:** Previous, Play/Pause toggle, and Next track with keyboard and click navigation.

### 4. 🗓️ Smart Calendar & 1-Click Video Call Launcher
- **Next Meeting Countdown:** Always know what’s next without opening your calendar (`"In 8m: Architecture Review"`, `"Happening Now"`).
- **1-Click Call Join:** Intelligent regex engine parses meeting invites and renders an instant one-click join button for:
  - 🟢 **Google Meet** (`meet.google.com/...`)
  - 🔵 **Zoom** (`zoom.us/j/...`)
  - 🟣 **Microsoft Teams** (`teams.microsoft.com/...`)
  - 🟠 **Cisco Webex** (`webex.com/...`)
- **Full Today Agenda:** Inspect remaining events scheduled for the day.

### 5. 🪞 Quick Camera Mirror
- **Pre-Call Appearance Check:** Open the Mirror tab to verify your lighting, framing, and background before joining a video conference.
- **Zero LED Leakage:** The `AVCaptureSession` is strictly initialized only when the Mirror tab is visible and shuts down the moment you switch tabs or collapse the island, ensuring the green hardware LED never remains illuminated in the background.
- **Camera Device Switcher:** Easily toggle between built-in FaceTime HD cameras and external studio webcams.

### 6. 📥 Temporary File Shelf & 1-Click AirDrop
- **Drop to Stash:** Drag any file or folder directly onto the notch to park it temporarily while switching desktop spaces or applications.
- **Quick AirDrop:** Beam individual staged files or all files at once via native macOS AirDrop (`NSSharingService`).
- **Drag-Out Everywhere:** Drag staged files directly out of OpenHalo into Slack, Mail, WhatsApp, Discord, or Finder.

### 7. 📊 Live System Telemetry & Brightness Control
- **Mach Kernel CPU Telemetry:** Live per-core processor load via `host_processor_info`.
- **Memory Consumption:** Active RAM utilization breakdown via `host_statistics64`.
- **Battery & AC Health:** Direct battery percentage, adapter status, and charging state via `IOKit/IOPowerSources`.
- **Integrated Display Brightness Slider:** Seamlessly adjust display illumination right from the island deck.
- **Zero Idle Overhead:** Telemetry polling is automatically suspended when the island collapses!

### 8. ⏱️ Productivity Timers & Pomodoro Rings
- Quick presets for **1 minute**, **5 minutes**, **15 minutes**, and **25-minute Pomodoro sprints**.
- Visual circular countdown rings with play, pause, reset, and chime audio alerts.

### 9. 🎙️ Zero-Permission Microphone Security Dot
- Alerts you the exact moment any application accesses audio input on your Mac.
- Built via CoreAudio HAL property listeners (`kAudioDevicePropertyDeviceIsRunningSomewhere`).
- **Never reads or records audio buffers**—100% private with zero microphone permission prompts!

---

## 🔒 Security & Privacy Manifesto

At OpenHalo, user privacy is non-negotiable.

```
┌─────────────────────────────────────────────────────────────────┐
│                    ZERO-TELEMETRY GUARANTEE                     │
│                                                                 │
│  ✓ 0 Outbound Network Requests (Runs 100% offline)              │
│  ✓ 0 Analytics, Crash Reporters, or Telemetry Trackers          │
│  ✓ 0 Cloud Accounts or API Keys Required                        │
│  ✓ 0 Audio Recording Buffers Captured                           │
│  ✓ Camera Session Shuts Down Immediately Upon Tab Collapse      │
└─────────────────────────────────────────────────────────────────┘
```

1. **Non-Activating Windowing Engine**: OpenHalo runs as a non-activating `NSPanel` at the `.statusBar` window level. It will never steal key focus or interrupt you while you are actively typing in your IDE, terminal, or document editors.
2. **Local macOS APIs Only**: All functionality is powered directly by Apple's own system APIs: `EventKit`, `CoreAudio`, `IOKit`, `AppKit`, `AVFoundation`, and `SwiftUI`.

---

## ⌨️ Global Shortcuts & Navigation

| Shortcut | Action |
| :--- | :--- |
| `⌘ + ⌃ + I` | Toggle Dynamic Island (Expand / Collapse) |
| `⌘ + 1` | Switch to **Media Player** Tab |
| `⌘ + 2` | Switch to **Calendar & Meeting** Tab |
| `⌘ + 3` | Switch to **Timers & Pomodoro** Tab |
| `⌘ + 4` | Switch to **System Health & Brightness** Tab |
| `⌘ + 5` | Switch to **File Shelf & AirDrop** Tab |
| `⌘ + 6` | Switch to **Quick Camera Mirror** Tab |
| **Hover** | Peek into island status (auto-collapses on cursor exit) |
| **Drag & Drop** | Drag files directly over the notch to stash them |

---

## 🚀 Installation & Quick Start

### Option 1: Download Pre-Built Application Bundle
1. Download the latest release from the [Releases](https://github.com/nikhil2001gowda/OpenHalo/releases) page.
2. Unzip and drag `OpenHalo.app` into your `/Applications` folder.
3. Open the app. The discreet menu bar icon will appear and the Dynamic Island will dock neatly over your notch!

### Option 2: Build From Source

Requirements: macOS 14.0+ (Sonoma or Sequoia) and Xcode 15+ / Swift 5.9+.

```bash
# Clone the repository
git clone https://github.com/nikhil2001gowda/OpenHalo.git
cd OpenHalo

# Run automated tests and assertions
swift run OpenHaloVerify

# Build the release application bundle
./scripts/build_app.sh

# Launch OpenHalo
open build/OpenHalo.app
```

---

## 🏗️ Repository Architecture

```
OpenHalo/
├── Package.swift                             # Swift Package Manager manifest
├── Sources/
│   ├── OpenHaloApp/
│   │   └── OpenHaloApp.swift                 # Application entry point (@main)
│   ├── OpenHalo/
│   │   ├── App/
│   │   │   └── AppDelegate.swift             # Menu bar extra & window coordinator
│   │   ├── Coordinator/
│   │   │   ├── IslandCoordinator.swift      # Central state machine & service lifecycle
│   │   │   └── IslandState.swift             # Tab models & presentation states
│   │   ├── Windowing/
│   │   │   ├── IslandPanel.swift             # Non-activating floating NSPanel (.statusBar)
│   │   │   ├── IslandWindowController.swift  # Notch positioning & screen geometry listener
│   │   │   └── ScreenNotchDetector.swift     # Safe area insets & floating pill fallback
│   │   ├── Services/
│   │   │   ├── MediaService.swift            # Apple Music & Spotify notification observer
│   │   │   ├── SystemControlService.swift    # CoreAudio volume & display brightness
│   │   │   ├── CalendarService.swift         # EventKit schedule & meeting URL parser
│   │   │   ├── MirrorService.swift           # Low-latency camera check with safe cutoff
│   │   │   ├── AudioActivityMonitor.swift    # Zero-TCC CoreAudio mic stream listener
│   │   │   ├── BatteryService.swift          # IOKit power status observer
│   │   │   ├── HardwareMonitorService.swift  # Mach kernel CPU/RAM telemetry
│   │   │   ├── TimerService.swift            # DispatchSource precision countdown engine
│   │   │   └── FileShelfService.swift        # Drag-and-drop staging & AirDrop
│   │   ├── Models/
│   │   │   ├── CalendarEventItem.swift       # Event models & regex meeting link detector
│   │   │   ├── PillSlotConfig.swift          # Configurable Left/Right wing slot enums
│   │   │   ├── MediaTrack.swift              # Audio track metadata & progress formatting
│   │   │   ├── SystemMetrics.swift           # CPU, memory, and battery models
│   │   │   └── ShelfItem.swift               # Staged file item with QuickLook icons
│   │   ├── Views/
│   │   │   ├── IslandRootView.swift          # Dynamic spring capsule container
│   │   │   ├── CompactPillView.swift         # Configurable idle capsule pill
│   │   │   ├── ExpandedCardView.swift        # 6-tab navigation deck
│   │   │   ├── MediaExpandedView.swift       # Media player + volume slider
│   │   │   ├── CalendarExpandedView.swift    # Next meeting + 1-click video call join
│   │   │   ├── MirrorExpandedView.swift      # Live camera mirror look
│   │   │   ├── TimerExpandedView.swift       # Pomodoro presets & countdown ring
│   │   │   ├── SystemHealthView.swift        # CPU/RAM/Battery + brightness slider
│   │   │   ├── FileShelfView.swift           # Staged files + AirDrop
│   │   │   └── SettingsView.swift            # Modern preferences window
│   │   └── Utils/
│   │       ├── AppleScriptRunner.swift       # Safe, asynchronous AppleScript executor
│   │       └── SoundEffectManager.swift      # Native macOS audio alert player
│   └── OpenHaloVerify/
│       └── main.swift                        # Automated test & assertion suite
├── design/
│   └── tokens.json                           # SF Pro typography, radii, and spring tokens
├── docs/
│   └── ARCHITECTURE.md                       # In-depth technical architecture document
├── scripts/
│   └── build_app.sh                          # Release packaging & codesigning script
├── .github/workflows/
│   └── build.yml                             # Automated CI build & test action
├── CONTRIBUTING.md                            # Open source contribution guidelines
└── LICENSE                                   # MIT License
```

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make to OpenHalo are **greatly appreciated**!

Please see our [Contributing Guide](CONTRIBUTING.md) for details on code style, architectural invariants, and submitting pull requests.

---

## 📄 License

OpenHalo is released under the **MIT License**. See [LICENSE](LICENSE) for full details.

---

<div align="center">

**Built with ❤️ for the macOS Community by [Nikhil Gowda](https://github.com/nikhil2001gowda)**

*If you love OpenHalo, please star ⭐ the repository to support development and help others discover it!*

</div>
