<div align="center">

# OpenHalo 🏝️✨
### The Ultimate Native Dynamic Island for macOS
*(Synthesizing the Best of Halo, Boring Notch, Droppy, MediaMate, NotchNook, Alcove, Atoll & Notchy)*

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
   ╭───────────────────────────────────────────────────╮
   │  [♫ Media] [🗓️ Meet] [⏱️ Timers] [🎯 Focus] [📋]   │
   │  ───────────────────────────────────────────────  │
   │  M83 — Hurry Up, We're Dreaming                   │
   │  ⏮   ▶⏸   ⏭   ───●──── 🔊 [====|====]            │
   │                                                   │
   │  🗓️ In 12m: Architecture & Product Review          │
   │  [ 🟢 Join Google Meet ]                           │
   ╰───────────────────────────────────────────────────╯
                    ▼ (Volume Key Pressed)
     ╭───────────────────────────────╮
     │  🔊  [==========|====]  75%   │   ← MediaMate iOS HUD Popup
     ╰───────────────────────────────╯
```

**OpenHalo** unites the standout capabilities of every major notch and island utility into a single, cohesive, ultra-fast application. Control music, replace ugly system volume HUDs with fluid iOS sliders, search clipboard history, launch pinned apps, join video meetings with one click, run on-device vision presence checks, and stash files for instant AirDrop.

**No subscriptions. No cloud accounts. No background telemetry. Pure native Swift.**

---

</div>

## 💡 The Grand Comparison: OpenHalo vs. The Ecosystem

Why pay monthly subscriptions or buy 4 separate utilities when you can have everything in one native, privacy-preserving open-source tool?

| Capability / App Inspiration | OpenHalo (Free & Open Source) | Standalone Paid Apps |
| :--- | :---: | :---: |
| **Pricing** | **100% Free Forever (MIT)** | $10–$25 each, or recurring subs |
| **MediaMate Style Native HUDs** | **Built-in iOS volume/brightness popups** | MediaMate ($9.20) |
| **Droppy Style Clipboard Manager** | **Full history, search, & 1-click copy** | Droppy ($9.99) / NotchNook ($25) |
| **NotchNook Style App Launcher** | **App dock & web bookmarks in notch** | NotchNook ($25) / Atoll |
| **Alcove Style Live Focus Ticker** | **Wing slot ticker & daily checklist** | Alcove ($14.99) |
| **Notchy Style Vision Presence** | **100% On-Device Apple Vision checks** | Notchy ($24.99) |
| **Halo & Boring Notch Core** | **Music scrubber, calendar, mirror, shelf** | Halo ($19) / Boring Notch |
| **Telemetry & Outbound Network** | **0 Requests (100% Offline)** | Cloud analytics / telemetry |
| **Microphone Privacy** | **Zero-TCC HAL Listener (0 buffers)** | Mic recording prompts |
| **Battery Impact** | **Near-Zero (Suspended when idle)** | Often heavy background polling |

---

## 🌟 Complete Feature Deck (9-Tab Cockpit)

### 1. 🔊 MediaMate Native HUD Replacement
- **Drop-Down iOS Sliders:** Replaces the default macOS volume and display brightness overlay boxes with smooth, rounded iOS pill sliders descending directly from the notch.
- **Hardware Key Interception:** Listens to CoreAudio HAL property notifications (`kAudioDevicePropertyVolumeScalar`) when function keys (F11/F12) are pressed.
- **Auto-Dismiss:** Drops down fluidly and auto-retracts back into the notch after 1.8 seconds.

### 2. 📋 Droppy & NotchNook Clipboard History Manager
- **Automatic Clipboard Interception:** Monitors `NSPasteboard` changes and caches recent clippings locally in memory.
- **Smart Content Detection:** Automatically categorizes clips into `Link`, `Color Hex`, `Code`, and `Text` with distinct color badges.
- **Instant Search & 1-Click Copy:** Fast substring filter and copy-back to clipboard with visual toast alerts.

### 3. 🚀 NotchNook & Atoll App & Bookmark Launcher Dock
- **Quick Dock:** Pinned favorites dock right inside the Dynamic Island for Finder, Safari, Terminal, Notes, Slack, Xcode, and custom web URLs.
- **1-Click Launch:** Launches applications or opens browser bookmarks with native `NSWorkspace` execution.

### 4. 🎯 Alcove Live Focus Objective & Task Ticker
- **Notch Wing Ticker:** Pin your primary focus goal (*"Ship OpenHalo v3"*) directly into the compact notch pill wing!
- **Daily Checklist:** Add, toggle, and manage quick tasks with instant visual strikethrough and completion counters.

### 5. 👁️ Notchy On-Device Vision Presence & Face Detection
- **100% On-Device Machine Learning:** Leverages Apple's native `Vision` framework (`VNDetectFaceRectanglesRequest`) running on the Apple Neural Engine.
- **Strict Single-Burst Hygiene:** Captures exactly 1 frame on user request, analyzes presence, and shuts down the camera session immediately. The green hardware camera LED never latches on!

### 6. 🎵 Universal Media Center & Audio Controls
- **Apple Music & Spotify Support:** Automatically tracks song metadata, artist, album, and artwork via `DistributedNotificationCenter`.
- **Full Interactive Deck:** Click-to-seek scrubber, transport buttons, master CoreAudio volume slider, and live animated equalizer waveform visualizer.

### 7. 🗓️ Smart Calendar & 1-Click Meeting Join
- **Live Countdown:** Displays remaining time until your next event (*"In 12m: Architecture Review"*).
- **1-Click Video Call Launcher:** Intelligent regex engine extracts join links for:
  - 🟢 **Google Meet** (`meet.google.com/...`)
  - 🔵 **Zoom** (`zoom.us/j/...`)
  - 🟣 **Microsoft Teams** (`teams.microsoft.com/...`)
  - 🟠 **Cisco Webex** (`webex.com/...`)

### 8. 📥 File Shelf & Instant AirDrop Stash
- **Drop to Stash:** Drag files or folders directly over the notch to hold them temporarily while navigating between desktop spaces.
- **Native AirDrop:** Beam individual staged files or all files simultaneously via `NSSharingService`.
- **Drag-Out:** Drag files directly into Slack, Mail, WhatsApp, or Finder.

### 9. 📊 Hardware Telemetry & Brightness Control
- Real-time CPU usage meter via Mach kernel APIs (`host_processor_info`).
- RAM memory utilization (used GB / total GB) via `host_statistics64`.
- Battery percentage, power adapter status, and charging state via `IOKit/IOPowerSources`.
- Integrated display brightness slider.
- Zero CPU overhead when collapsed!

---

## 🔒 Security & Privacy Manifesto

```
┌─────────────────────────────────────────────────────────────────┐
│                    ZERO-TELEMETRY GUARANTEE                     │
│                                                                 │
│  ✓ 0 Outbound Network Requests (Runs 100% offline)              │
│  ✓ 0 Analytics, Crash Reporters, or Telemetry Trackers          │
│  ✓ 0 Cloud Accounts or API Keys Required                        │
│  ✓ 0 Audio Recording Buffers Captured (CoreAudio HAL only)      │
│  ✓ Camera Shuts Down Immediately Upon Tab Collapse / Scan       │
└─────────────────────────────────────────────────────────────────┘
```

1. **Non-Activating Windowing Engine**: OpenHalo runs as a non-activating `NSPanel` at `.statusBar` level. Typing in Xcode, Terminal, or Slack is never interrupted. Focus is only temporarily enabled during active search or note editing.
2. **Apple Frameworks Exclusively**: 100% standard library and Apple system SDKs (`Vision`, `CoreAudio`, `IOKit`, `EventKit`, `AppKit`, `SwiftUI`, `AVFoundation`).

---

## ⌨️ Global Shortcuts & Navigation

| Shortcut | Action |
| :--- | :--- |
| `⌘ + ⌃ + I` | Toggle Dynamic Island (Expand / Collapse) |
| `⌘ + 1` | Switch to **Media Player** Tab |
| `⌘ + 2` | Switch to **Calendar & Meeting** Tab |
| `⌘ + 3` | Switch to **Timers & Pomodoro** Tab |
| `⌘ + 4` | Switch to **Focus Task & Notes** Tab |
| `⌘ + 5` | Switch to **Clipboard History** Tab |
| `⌘ + 6` | Switch to **App & Bookmark Launcher** Tab |
| `⌘ + 7` | Switch to **System Health & Brightness** Tab |
| `⌘ + 8` | Switch to **File Shelf & AirDrop** Tab |
| `⌘ + 9` | Switch to **Quick Camera Mirror & Vision** Tab |
| **Hover** | Peek into island status (auto-collapses on cursor exit) |
| **Drag & Drop** | Drag files directly over the notch to stash them |

---

## 🚀 Installation & Quick Start

### Build & Run From Source

Requirements: macOS 14.0+ (Sonoma or Sequoia) and Xcode 15+ / Swift 5.9+.

```bash
# Clone the repository
git clone https://github.com/nikhil2001gowda/OpenHalo.git
cd OpenHalo

# Run automated verification suite (11 test suites)
swift run OpenHaloVerify

# Build and package the release application
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
│   │   │   └── AppDelegate.swift             # Menu bar extra & global shortcuts
│   │   ├── Coordinator/
│   │   │   ├── IslandCoordinator.swift      # Central state machine & HUD orchestrator
│   │   │   └── IslandState.swift             # HUDPayload & 9 ExpandedTab definitions
│   │   ├── Windowing/
│   │   │   ├── IslandPanel.swift             # Non-activating floating NSPanel (.statusBar)
│   │   │   ├── IslandWindowController.swift  # Notch positioning & screen geometry listener
│   │   │   └── ScreenNotchDetector.swift     # Safe area insets & floating pill fallback
│   │   ├── Services/
│   │   │   ├── SystemControlService.swift    # CoreAudio volume key listener & brightness
│   │   │   ├── ClipboardHistoryService.swift # NSPasteboard history & search engine
│   │   │   ├── AppLauncherService.swift      # Pinned apps & web bookmark manager
│   │   │   ├── FocusNoteService.swift        # Focus headline goal & daily checklist
│   │   │   ├── PresenceDetectionService.swift# Apple Vision on-device face detector
│   │   │   ├── MediaService.swift            # Apple Music & Spotify observer
│   │   │   ├── CalendarService.swift         # EventKit schedule & meeting URL parser
│   │   │   ├── MirrorService.swift           # Low-latency camera check with safe cutoff
│   │   │   ├── AudioActivityMonitor.swift    # Zero-TCC CoreAudio mic stream listener
│   │   │   ├── BatteryService.swift          # IOKit power status observer
│   │   │   ├── HardwareMonitorService.swift  # Mach kernel CPU/RAM telemetry
│   │   │   ├── TimerService.swift            # DispatchSource precision countdown engine
│   │   │   └── FileShelfService.swift        # Drag-and-drop staging & AirDrop
│   │   ├── Models/
│   │   │   ├── ClipboardItem.swift           # Clip model with type auto-classification
│   │   │   ├── LauncherShortcut.swift        # App & bookmark shortcut models
│   │   │   ├── FocusTaskItem.swift           # Daily checklist item model
│   │   │   ├── CalendarEventItem.swift       # Event models & regex meeting link detector
│   │   │   ├── PillSlotConfig.swift          # Configurable Left/Right wing slot enums
│   │   │   ├── MediaTrack.swift              # Audio track metadata & progress formatting
│   │   │   ├── SystemMetrics.swift           # CPU, memory, and battery models
│   │   │   └── ShelfItem.swift               # Staged file item with QuickLook icons
│   │   ├── Views/
│   │   │   ├── IslandRootView.swift          # Dynamic spring capsule container
│   │   │   ├── CompactPillView.swift         # Configurable idle capsule pill with focus ticker
│   │   │   ├── MediaMateHUDView.swift        # Drop-down iOS volume & brightness pill slider
│   │   │   ├── ExpandedCardView.swift        # 9-tab adaptive navigation deck
│   │   │   ├── ClipboardExpandedView.swift   # Searchable clipboard history manager
│   │   │   ├── LauncherExpandedView.swift    # Pinned app & web bookmark dock
│   │   │   ├── FocusNoteExpandedView.swift   # Primary focus goal & checklist
│   │   │   ├── MediaExpandedView.swift       # Media player + volume slider
│   │   │   ├── CalendarExpandedView.swift    # Next meeting + 1-click video call join
│   │   │   ├── MirrorExpandedView.swift      # Live camera look & Vision presence
│   │   │   ├── TimerExpandedView.swift       # Pomodoro presets & countdown ring
│   │   │   ├── SystemHealthView.swift        # CPU/RAM/Battery + brightness slider
│   │   │   ├── FileShelfView.swift           # Staged files + AirDrop
│   │   │   └── SettingsView.swift            # Preferences window & module toggles
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
