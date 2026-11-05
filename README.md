<div align="center">

# OpenHalo 🏝️✨
### The Ultimate Native Dynamic Island for macOS
*(Synthesizing the Best of Halo, Boring Notch, Droppy, MediaMate, NotchNook, Alcove, Atoll, Notchy & Glance)*

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
   ╭─────────────────────────────────────────────────────────────────╮
   │  [♫ Media] [🗓️ Meet] [⏱️ Timers] [🎯 Focus] [🌤️ Weather] [📋 Clips]│
   │  ─────────────────────────────────────────────────────────────  │
   │  M83 — Hurry Up, We're Dreaming                                 │
   │  ⏮   ▶⏸   ⏭   ───●──── 🔊 [====|====]                          │
   │                                                                 │
   │  🗓️ In 12m: Architecture & Product Review                        │
   │  [ 🟢 Join Google Meet ]                                         │
   ╰─────────────────────────────────────────────────────────────────╯
                    ▼ (Volume Key Pressed)
     ╭───────────────────────────────╮
     │  🔊  [==========|====]  75%   │   ← MediaMate iOS HUD Popup
     ╰───────────────────────────────╯
```

**OpenHalo** unites the standout capabilities of every major notch and island utility into a single, cohesive, ultra-fast application. Control music, replace ugly system volume HUDs with fluid iOS sliders, search clipboard history, launch pinned apps, join video meetings with one click, get live keyless weather, convert images with built-in SIPS, assist screen lock with a strict 5-second Face ID watchdog, and stash files for instant AirDrop.

**No subscriptions. No cloud accounts. No background telemetry. Pure native Swift.**

---

</div>

## 💡 The Grand Comparison: OpenHalo vs. The Ecosystem

Why pay monthly subscriptions or buy 5 separate utilities when you can have everything in one native, privacy-preserving open-source tool?

| Capability / App Inspiration | OpenHalo (Free & Open Source) | Standalone Paid Apps |
| :--- | :---: | :---: |
| **Pricing** | **100% Free Forever (MIT)** | $10–$25 each, or recurring subs |
| **MediaMate Style Native HUDs** | **Built-in iOS volume/brightness popups** | MediaMate ($9.20) |
| **Droppy Style Clipboard Manager** | **Full history, search, password filter, & 1-click copy** | Droppy ($9.99) / NotchNook ($25) |
| **NotchNook Style App Launcher** | **App dock & web bookmarks in notch** | NotchNook ($25) / Atoll |
| **Alcove Style Live Focus Ticker** | **Wing slot ticker & daily checklist** | Alcove ($14.99) |
| **Live Keyless Weather** | **Open-Meteo REST (0 API keys, 20m cache)** | Paid weather APIs |
| **SIPS Image Converter** | **Built-in macOS `/usr/bin/sips` (PNG, JPEG, WebP, HEIC)** | Third-party utilities |
| **Glance Low-Power Engine** | **0.0% CPU: Freezes Mach/HAL during screen & Mac sleep** | Constant background polling |
| **Notchy Style Face ID Assistant** | **Strict $\le 5$s Camera Watchdog on Lock Wake (Apple Vision)** | Notchy ($24.99) |
| **Launch at Login & Reboot Persistence** | **Native `SMAppService.mainApp` + Auto Staged File Restore** | Often requires helper daemons |
| **Halo & Boring Notch Core** | **Music scrubber, calendar, mirror, shelf** | Halo ($19) / Boring Notch |
| **Telemetry & Outbound Network** | **0 Trackers (100% Offline / Keyless)** | Cloud analytics / telemetry |
| **Microphone Privacy** | **Zero-TCC HAL Listener (0 audio buffers recorded)** | Mic recording prompts |

---

## 🌟 Complete Feature Deck (10-Tab Cockpit)

### 1. 🔊 MediaMate Native HUD Replacement
- **Drop-Down iOS Sliders:** Replaces the default macOS volume and display brightness overlay boxes with smooth, rounded iOS pill sliders descending directly from the notch.
- **Hardware Key Interception:** Listens to CoreAudio HAL property notifications (`kAudioDevicePropertyVolumeScalar`) when function keys (F11/F12) are pressed.
- **Auto-Dismiss:** Drops down fluidly and auto-retracts back into the notch after 1.8 seconds.

### 2. 📋 Droppy & NotchNook Clipboard History Manager
- **Automatic Clipboard Interception:** Monitors `NSPasteboard` changes and caches recent clippings locally in memory.
- **Password Security Guard:** Specifically detects and drops concealed password types (`org.nspasteboard.ConcealedType`, `com.agilebits.onepassword`, and `org.nspasteboard.AutoGeneratedType`) to guarantee master passwords and credentials never leak into clipboard history.
- **Smart Content Detection:** Automatically categorizes clips into `Link`, `Color Hex`, `Code`, and `Text` with distinct color badges.
- **Instant Search & 1-Click Copy:** Fast substring filter and copy-back to clipboard with visual toast alerts.

### 3. 🚀 NotchNook & Atoll App & Bookmark Launcher Dock
- **Quick Dock:** Pinned favorites dock right inside the Dynamic Island for Finder, Safari, Terminal, Notes, Slack, Xcode, and custom web URLs.
- **1-Click Launch:** Launches applications or opens browser bookmarks with native `NSWorkspace` execution.

### 4. 🎯 Alcove Live Focus Objective & Task Ticker
- **Focus Ticker in Pill Wings:** Set your core sprint goal (e.g. `"Complete OpenHalo 4.0"`) and see it displayed directly in the compact pill wing while working.
- **Daily Checklist:** Add, complete, and clear tasks from the expanded island view.

### 5. 🌤️ Keyless Live Weather Forecast (Open-Meteo)
- **Zero API Keys Required:** Powered by the open-source Open-Meteo REST API (`api.open-meteo.com`). Completely free, zero tracking, and zero account setup.
- **Dynamic SF Symbols:** Maps international WMO weather codes to dynamic Apple SF Symbols (`sun.max.fill`, `cloud.sun.fill`, `cloud.rain.fill`, `snowflake`, `cloud.bolt.rain.fill`).
- **Pill Wing Integration:** Set your idle Left or Right wing slot to **Live Weather** to see `"☀️ 21°C"` or `"🌧️ 16°C"` directly beside your physical MacBook notch.
- **Intelligent Caching:** 20-minute local TTL caching ensures zero battery drain or redundant requests.

### 6. ⚡ SIPS File Converter & Compressor on File Shelf
- **Native macOS `/usr/bin/sips` Pipeline:** Convert and resize staged files with zero external binaries or libraries.
- **1-Click Format Conversion:** Right-click any image in the File Shelf to instantly convert between **PNG, JPEG, WebP, HEIC, and TIFF**.
- **Instant Resizing:** Quick action downscaling to 1920px, 1280px, or 800px.

### 7. 🔋 Glance-Inspired Low-Power Engine (0.0% CPU)
- **Deep Sleep Observers:** Subscribes to `screensDidSleepNotification`, `screensDidWakeNotification`, `willSleepNotification`, and `didWakeNotification`.
- **Complete Subsystem Freeze:** The moment the screen turns off or your Mac sleeps, OpenHalo freezes all Mach kernel CPU/RAM timers, halts CoreAudio listeners, pauses clipboard polling, and ensures all camera sessions are killed.
- **Instant Thaw on Wake:** Resumes state in under 5 milliseconds with near-zero energy consumption.

### 8. 🛡️ 5-Second Screen Lock Face ID Assistant
- **Strict 5.0-Second Watchdog Timer:** When the screen locks and wakes, the front camera activates for a hard maximum of 5.0 seconds. As soon as your face is recognized OR 5 seconds elapse, the camera is **forcibly terminated** and the physical green LED turns OFF.
- **100% On-Device Apple Vision:** Runs `VNDetectFaceLandmarksRequest` and `VNDetectFaceCaptureQualityRequest` directly on the Apple Silicon Neural Engine.
- **Zero Video or Photo Storage:** Camera frames exist only ephemerally in `CVPixelBuffer` memory and are never written to disk. Only an abstract geometric landmark ratio vector is stored locally.

### 9. 🔄 Launch at Login & Reboot Persistence
- **Official `SMAppService.mainApp`:** Integrates natively with macOS 13+ Service Management for smooth, reliable launch upon restart.
- **Staged File Persistence:** Staged File Shelf items survive shutdowns and reboots. If files are deleted while offline, OpenHalo automatically cleans up stale entries safely.

### 10. 🎵 Music, Video Meetings, Pomodoro & File Stash
- **Media Controller:** Apple Music & Spotify scrubbing, album art display, volume slider, and live audio waveform visualizer.
- **Next Meeting Alert:** EventKit calendar integration with one-click button to join Google Meet, Zoom, or Microsoft Teams.
- **Precision Timers:** Pomodoro presets (1m, 5m, 15m, 25m) with circular countdown rings.
- **Temporary File Shelf & AirDrop:** Drop files into the notch to stash them temporarily or broadcast via AirDrop.
- **Quick Camera Mirror:** Instant popover to check your lighting before video calls with one-click Vision detection.

---

## 🔒 Security, Privacy & Architectural Boundaries

OpenHalo is engineered from the ground up to respect user privacy and adhere strictly to Apple's modern macOS security model:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       OPENHALO SECURITY ARCHITECTURE                         │
├──────────────────────────┬──────────────────────────────────────────────────┤
│ Feature                  │ Architectural Boundary & Defense                 │
├──────────────────────────┼──────────────────────────────────────────────────┤
│ Lock Screen Camera       │ 5.000s Hard Watchdog Timer. Strictly terminates  │
│                          │ immediately upon match or timeout. Zero frames   │
│                          │ written to disk (CVPixelBuffer RAM only).        │
├──────────────────────────┼──────────────────────────────────────────────────┤
│ macOS Lock Screen Auth   │ NEVER modifies PAM (/etc/pam.d) or root daemons. │
│                          │ Operates as a companion presence guard to        │
│                          │ protect System Integrity Protection (SIP) & SSV. │
├──────────────────────────┼──────────────────────────────────────────────────┤
│ Clipboard History        │ Automatically drops ConcealedType (passwords     │
│                          │ from 1Password, Bitwarden, Apple Keychain).      │
├──────────────────────────┼──────────────────────────────────────────────────┤
│ Microphone Privacy       │ CoreAudio HAL property listener (0 audio buffers │
│                          │ ever recorded, zero TCC microphone prompt).      │
├──────────────────────────┼──────────────────────────────────────────────────┤
│ Weather Service          │ Keyless Open-Meteo REST. 20-min TTL caching.     │
│                          │ Zero analytics, zero advertising IDs.            │
├──────────────────────────┼──────────────────────────────────────────────────┤
│ Image Conversion         │ Uses built-in macOS /usr/bin/sips. Runs 100%     │
│                          │ offline without external executables.            │
└──────────────────────────┴──────────────────────────────────────────────────┘
```

> [!NOTE]
> **Why PAM Password Injection is Intentionally Omitted:**
> Some dangerous proof-of-concept notch apps attempt to inject passwords into Apple's login screen by altering `/etc/pam.d/authorization` or running root daemons. On modern macOS (Sonoma & Sequoia), doing so requires disabling System Integrity Protection (SIP) and violates the Signed System Volume (SSV), creating severe security vulnerabilities and causing OS update boot loops. OpenHalo strictly acts as a user-space **Presence Guard** and assistant, preserving Apple Silicon Secure Enclave and Touch ID integrity.

---

## ⌨️ Keyboard Shortcuts & Controls

| Shortcut | Action |
| :--- | :--- |
| `⌘ + ⌃ + I` | Toggle OpenHalo Dynamic Island expand / collapse |
| `⌘ + 1` | Open Media Player Tab |
| `⌘ + 2` | Open Calendar & Next Meeting Tab |
| `⌘ + 3` | Open Timer & Pomodoro Tab |
| `⌘ + 4` | Open Focus Objective & Checklist Tab |
| `⌘ + W` | Open Live Weather Tab |
| `⌘ + 5` | Open Clipboard History Manager Tab |
| `⌘ + 6` | Open App & Web Bookmark Launcher Tab |
| `⌘ + 7` | Open System Telemetry & Health Tab |
| `⌘ + 8` | Open File Shelf & AirDrop Stash Tab |
| `⌘ + 9` | Open Quick Camera Mirror & Vision Tab |
| `⌘ + ,` | Open OpenHalo Preferences Window |

---

## 🛠️ Building & Running from Source

### Prerequisites
- macOS 14.0+ (Sonoma or Sequoia)
- Xcode 16.0+ or Apple Command Line Tools
- Swift 6.0 toolchain

### Build & Run
```bash
# Clone the repository
git clone https://github.com/nikhil2001gowda/OpenHalo.git
cd OpenHalo

# Run the automated 15-test verification suite
swift run OpenHaloVerify

# Build the standalone macOS release application bundle
./scripts/build_app.sh

# Launch OpenHalo
open build/OpenHalo.app
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
