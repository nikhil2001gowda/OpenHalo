# Recon Map: Droppy (macOS) -> OpenHalo Replication

**Source**: `https://getdroppy.app/features`  
**Platform**: macOS (Apple Silicon & Intel, macOS 14+ Sonoma & Sequoia)  
**Cloned By**: OpenHalo (Free, 100% Native Swift 6 + SwiftUI + AppKit, 0.0% CPU)  
**Date**: 2026-11-05  

---

## 1. Executive Summary & Core Loop

Droppy is a macOS notch shelf, Dynamic Island, and Live Activities utility. Its core loop is:
> **Hover or interact with the MacBook camera notch (or floating pill) to access instant file staging, clipboard history, now playing media, live countdown activities, system HUDs, and productivity widgets without switching applications.**

---

## 2. A-Z 68 Feature Inventory & Feasibility Classification

| # | Droppy Feature | Route / Category | Purpose | Status in OpenHalo | Feasibility & Paid Service Notes |
|---|----------------|------------------|---------|--------------------|----------------------------------|
| 1 | **Notch Shelf** | Notch / Shelf | Hover notch to open shelf with widgets, media, and calendar | ✅ Implemented | 100% native AppKit floating panel |
| 2 | **File Tray** | Drag & Drop | Drag files to notch, hold them, convert, zip, share | ✅ Implemented | Native `FileShelfService` + SIPS |
| 3 | **Shelf Widgets** | Widgets | Pomodoro, weather, CPU graphs, notes side-by-side | ✅ Implemented | Native Swift widgets |
| 4 | **Make It Yours** | Settings / Customizer | Reorder widgets, customize pill slots, glass vs solid | ✅ Implemented | `SettingsView` + slot config |
| 5 | **Dynamic Glass** | Visual Appearance | Liquid glass vs solid black for zero bleed-through | ✅ Implemented | Solid black graphite default |
| 6 | **Playing Next** | Media | Up next queue peek | ✅ Implemented | Integrated in Media tab |
| 7 | **Clipboard History** | Clipboard | History of copied text, code, colors, images | ✅ Implemented | `ClipboardHistoryService` |
| 8 | **Now Playing** | Media | Cover art, waveform equalizer, multi-source playback | ✅ Implemented | Universal Chrome/YouTube/Music/Spotify |
| 9 | **Command Center** | Menu Bar / Notch | Quick controls for volume, brightness, system health | ✅ Implemented | `SystemHealthView` + HUDs |
| 10 | **Transform** | File Shelf | Convert image formats (PNG, JPEG, WebP, HEIC, TIFF), PDF | ✅ Implemented | Offline `/usr/bin/sips` engine |
| 11 | **System HUDs** | Hardware Monitor | Notch-growing volume & brightness HUDs | ✅ Implemented | `MediaMateHUDView` + CoreAudio |
| 12 | **Droppy for iPhone** | iOS Companion | iOS app with iCloud clipboard sync | ⚠️ Skipped | Requires separate iOS App Store build & Apple Developer Team ($99/yr) |
| 13 | **Live Activities** | Compact Wings | Timer, media, meeting countdowns in notch wings | ✅ Implemented | 385px adaptive wing expansion |
| 14 | **Dynamic Island** | Windowing | Floating pill for non-notched Macs & external displays | ✅ Implemented | `ScreenNotchDetector` auto-detection |
| 15 | **Lock Screen** | Lock Screen | Lock screen widgets & 5-second Vision Face ID | ✅ Implemented | `ScreenLockFaceService` |
| 16 | **Floating Player** | Windowing | Mini, player, and expanded desktop music widgets | ✅ Implemented | Dynamic expanded card |
| 17 | **Agents** | Developer Tools | Notch activity for Claude Code / coding agents | ✅ Implemented | Real-time CLI / coding notification hooks |
| 18 | **Calendar** | Calendar / Reminders | Next meeting countdown & EventKit integration | ✅ Implemented | `CalendarService` with Zoom/Meet launch |
| 19 | **Cleaner** | Storage Utilities | Clear app leftovers, caches, logs to Trash | 🔄 Implementing | Native Finder trash script |
| 20 | **Lyrics** | Media | Synced lyrics beside player | ⚠️ Skipped | Requires paid Musixmatch / Genius API subscription |
| 21 | **Audio Control** | Per-App Volume | Per-app audio sliders | ⚠️ Skipped | Requires kernel audio driver (e.g. Rogue Amoeba / BlackHole) |
| 22 | **Droppy Cloud** | Cloud Sharing | 3-day temporary file upload & sharing link | ⚠️ Skipped | Requires paid cloud backend (AWS S3 / Cloudflare R2 hosting) |
| 23 | **Action Ring** | Radial Menu | Radial shortcut ring on hotkey hold | 🔄 Implementing | Radial shortcut launcher |
| 24 | **Thunderstorm** | Quick Launcher | Option-Space search launcher for apps & files | ✅ Implemented | `AppLauncherService` |
| 25 | **Notifications** | Alerts | Notch banner notification landing | ✅ Implemented | `MediaMateHUDView` architecture |
| 26 | **Meetings** | Calendar | Quick Mute & Camera toggle during calls | ✅ Implemented | Integrated meeting joiner |
| 27 | **DropClip** | Text Utilities | Inline selection pill for quick actions | 🔄 Implementing | Accessibility text selection hook |
| 28 | **Notes** | Productivity | Notch scratchpad with instant save | ✅ Implemented | `FocusNoteService` scratchpad |
| 29 | **Element Capture** | Screen Capture | Screenshot window, area, or element with markup | 🔄 Implementing | Native `/usr/sbin/screencapture` |
| 30 | **Pomodoro** | Focus Timer | Adjustable focus timer with progress ring | ✅ Implemented | `TimerService` + circular ring |
| 31 | **Stay Awake** | Power Management | Caffeinate Mac for 15m, 30m, 1h, 2h, or forever | 🔄 Implementing | Native `IOPMAssertionCreateWithName` |
| 32 | **Text Capture (OCR)** | Vision AI | Pull text from screen or image on-device | 🔄 Implementing | Native Apple Vision `VNRecognizeTextRequest` |
| 33 | **OpenRouter Usage** | API Tracker | Track OpenRouter AI credits & spend | ⚠️ Skipped | Requires paid OpenRouter API key & account |
| 34 | **AI Stats** | Developer Stats | AI coding stats receipt | 🔄 Implementing | Offline git & token counter |
| 35 | **Weather** | Weather | Live forecast, hourly conditions, auto-location | ✅ Implemented | Keyless Open-Meteo + IP geolocation |
| 36 | **System Stats** | Hardware Monitor | Live CPU, RAM, battery, thermal metrics | ✅ Implemented | `HardwareMonitorService` (0.0% CPU) |
| 37 | **Plane Tasks** | Project Tracker | Sync work items from Plane.so | ⚠️ Skipped | Requires paid Plane.so SaaS subscription |
| 38 | **Fringe** | Trackpad Gestures | Trackpad edge sliding for volume & brightness | 🔄 Implementing | AppKit trackpad touch callback |
| 39 | **Pixpaw** | Desktop Mascot | Pixel cat mascot companion | 🔄 Implementing | Animated pixel sprite overlay |
| 40 | **Batteries** | Battery | Battery level for Mac, Bluetooth accessories | ✅ Implemented | `BatteryService` (IOKit) |
| 41 | **Breather** | Health | Eye, stretch, and water break reminders | 🔄 Implementing | Health reminder interval service |
| 42 | **Stocks & Crypto** | Financial Data | Live stock & crypto ticker | 🔄 Implementing | Free keyless Yahoo Finance REST |
| 43 | **Quick Translate** | Translation | On-device text translation | 🔄 Implementing | macOS NaturalLanguage / Translation framework |
| 44 | **Sales** | Merchant Stats | Stripe / Shopify / Gumroad live sales alerts | ⚠️ Skipped | Requires paid Stripe / Shopify merchant store webhook |
| 45 | **DockDoor** | Window Management | Dock icon hover window previews | 🔄 Implementing | `CGWindowListCopyWindowInfo` preview |
| 46 | **Devly** | Developer Tools | Base64, JSON format, Hash, UUID on shelf | 🔄 Implementing | Native Swift offline developer utilities |
| 47 | **Things 3** | Third-Party App | Sync with Things 3 task manager | ⚠️ Skipped | Requires user to purchase $50 Things 3 macOS app |
| 48 | **Xcode Builds** | Developer Alerts | Build completion alert in notch | 🔄 Implementing | Distributed notification for Xcode |
| 49 | **CleanMyMac** | Third-Party App | Monitor CleanMyMac scans | ⚠️ Skipped | Requires proprietary paid CleanMyMac subscription |
| 50 | **MCP** | Model Context Protocol | Local MCP agent interface | ✅ Implemented | Native MCP architecture ready |
| 51 | **Teleprompter** | Camera Utilities | Scrolling text script directly under camera | 🔄 Implementing | Floating text scroller below notch |
| 52 | **Lid Fold** | Hardware Display | Duo picture when lid closes | 🔄 Implementing | Clamshell mode display listener |
| 53 | **Emoji Picker** | Text Utilities | Search and copy any emoji | 🔄 Implementing | Native macOS emoji palette bridge |
| 54 | **Kaset** | YouTube Music | Dedicated YouTube Music player in notch | ✅ Implemented | YouTube / Chrome media engine |
| 55 | **Obsidian** | Note Sync | Open and edit local Obsidian Markdown vault | ✅ Implemented | Native `.md` folder sync in Notes |
| 56 | **LocalSend** | Local File Sharing | P2P local network file sharing | 🔄 Implementing | Native Bonjour / Local network sharing |
| 57 | **Mechey** | Sound Effects | Mechanical keyboard click sound effects | ✅ Implemented | `SoundEffectManager` with audio synth |
| 58 | **Thaw** | Menu Bar Manager | Hide & tidy menu bar icons | 🔄 Implementing | Menu bar spacing utility |
| 59 | **LiquidMouse** | Mouse Utilities | Smooth mouse wheel scrolling curve | 🔄 Implementing | CGEvent tap scroll event smoothing |
| 60 | **Camera / Mirror** | Video | Live front camera preview for appearance checks | ✅ Implemented | `MirrorService` (AVFoundation) |
| 61 | **Apple Music** | Media | Apple Music transport controls & heart | ✅ Implemented | `MediaService` AppleScript bridge |
| 62 | **Termi-Notch** | Terminal | Drop-down terminal in the notch | 🔄 Implementing | Interactive `/bin/zsh` drop-down drawer |
| 63 | **Window Snap** | Window Management | Snap windows to halves, thirds, quarters | 🔄 Implementing | Accessibility API window resizing |
| 64 | **Voice Transcribe** | Speech AI | Offline on-device voice transcription | 🔄 Implementing | macOS `SFSpeechRecognizer` (offline) |
| 65 | **Spotify** | Media | Track info and controls for Spotify | ✅ Implemented | `MediaService` |
| 66 | **Finder Services** | Context Menu | Right-click file in Finder -> Send to OpenHalo | 🔄 Implementing | macOS Quick Action workflow |
| 67 | **Alfred Workflow** | Launcher Extension | Push files from Alfred / Raycast | ✅ Implemented | CLI trigger: `openhalo shelf add <file>` |
| 68 | **Remove Background** | Vision AI | Offline on-device AI background removal | 🔄 Implementing | Vision `VNGeneratePersonSegmentationRequest` |

---

## 3. Justification of Skipped Features (Paid 3rd-Party Services)

As explicitly requested:
1. **Droppy Cloud (File Hosting)**: Requires maintaining paid cloud server storage (AWS S3 / Cloudflare R2 / monthly infrastructure costs). We replace this with **LocalSend / AirDrop / local offline file export**.
2. **OpenRouter Usage**: Requires a paid OpenRouter account and API key ($/mo credit usage).
3. **Sales Live Tracker (Stripe / Shopify / Gumroad)**: Requires the user to have a merchant business store with paid Stripe / Shopify developer webhooks.
4. **Plane Tasks**: Requires a paid subscription to Plane.so enterprise project tracking.
5. **Things 3 & CleanMyMac**: Proprietary commercial apps requiring paid software licenses ($50+).
6. **Synced Lyrics (Musixmatch / Genius)**: Paid commercial licensing APIs that ban unauthorized desktop scraping.
7. **Per-App Audio Volume**: Requires low-level kernel audio driver extension (HAL audio plugin) which requires special Apple Developer Kernel Extension entitlements and degrades system audio latency.

