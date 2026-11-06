# Acknowledgements & Open-Source Credits

OpenHalo stands on the shoulders of brilliant open-source creators and designers in the macOS community. We believe in transparent attribution and giving full credit to the original authors, projects, and innovators whose code, UI/UX designs, and engineering breakthroughs made OpenHalo possible.

---

### 🌟 Primary Code & Architectural Foundations

#### 1. [Glance](https://github.com/jonathan-kosgei/glance)
- **Author:** [Jonathan Kosgei](https://github.com/jonathan-kosgei)
- **License:** GNU General Public License v3.0 (GPLv3)
- **Contributions to OpenHalo:**
  - **Lock Screen Face Recognition Engine:** The entire `Sources/OpenHalo/Glance/` subsystem, including `FaceRecognitionPipeline`, `ArcFaceEmbedder`, `VisionFeaturePrintEmbedder`, and `FaceEnrollmentStore`.
  - **Multi-Cue Liveness Detection Suite:** Advanced anti-spoofing algorithms including `DeviceBezelDetector`, `GeometryLiveness`, `GlareCueExtractor`, and `LivenessScoring`.
  - **Zero-Power Suspension Engine:** Deep sleep & display sleep observers that completely freeze Mach/HAL polling loops during sleep for 0.0% battery drain.
  - **Secure Credential Vault:** Two-tier Touch ID gated session key wrapping AES-GCM encrypted passwords via Apple Keychain (`SecureCredentialManager`, `POCController`).
  - **Notch Scanning Overlay & Visuals:** `NotchOverlayController`, `ScanAnimationView`, `EnrollmentRingView`, and the bundled lock screen unlock animations.
  - **Space Key Wake Trigger:** Low-level `IOKit.hid` event listener detecting spacebar taps on the lock screen.

#### 2. [Atoll](https://github.com/Ebullioscopic/Atoll)
- **Author:** [Ebullioscopic](https://github.com/Ebullioscopic) & Atoll Contributors
- **License:** GNU General Public License v3.0 (GPLv3)
- **Contributions to OpenHalo:**
  - **Fluid Spring Animation Physics:** The signature bouncy notch spring (`AtollAnimations.notchSpring`) and pill snapping curves (`AtollAnimations.pillSpring`).
  - **iOS Now Playing Volume Capsule Slider:** Tactile volume slider with hover swell, vertical touch expansion (`scaleEffect(y: 1.15)`), and progressive speaker glyph lighting (`AtollVolumeCapsuleSlider`).
  - **Continuous Smooth Marquee Text:** Fluid horizontal text scroller preventing truncation of long song titles and artist names (`AtollMarqueeText`).
  - **Tactile Horizontal Ruler Timer Picker:** Trackpad-scrubbable ruler with minute tick marks, center needle, inertia, and haptic feedback (`AtollRulerTimerPicker`).
  - **Apple Activity Ring Circular Metric Gauges:** Multi-stop arc progress meters with rounded caps and center readouts (`AtollCircularGaugeView`).
  - **Glowing Recording Indicator:** Multi-layered pulsating indicator dot with aura blur for active microphone and screen recording (`AtollRecordingIndicator`).
  - **Color-Coded Progress Bar:** Smooth Apple gradient progress bar transitioning dynamically between green, amber, and red (`AtollColorCodedProgressBar`).
  - **Neon Cursive "hello" Animation:** Glowing SVG path trace animation (`AtollHelloAnimation`).

#### 3. [Boring Notch](https://github.com/vashisthakshay/boring.notch)
- **Authors:** [Akshay Vashistha](https://github.com/vashisthakshay) & [Harsh Vashistha](https://github.com/harshv5094)
- **License:** GNU General Public License v3.0 (GPLv3)
- **Contributions to OpenHalo:**
  - Pioneering the open-source Dynamic Island concept on macOS.
  - Music visualizer bar architecture, core notch geometry detection principles, and media playback observer patterns.

---

### 🎨 UI/UX Design & Concept Inspirations

OpenHalo is also deeply inspired by several exceptional commercial and independent macOS utilities:

- **[MediaMate](https://wouter01.github.io/MediaMate/) by Wouter de Bres:** The original gold standard for replacing macOS's square volume and brightness HUDs with fluid notch-anchored iOS pill sliders.
- **[Droppy](https://droppy.app) & [NotchNook](https://lo score.com/notchnook):** Inspired the temporary drag-and-drop file shelf, quick action menus, and clipboard history popovers.
- **[Alcove](https://tryalcove.com):** Inspired the compact pill focus goal ticker and daily sprint checklist.
- **[Notchy](https://notchy.app):** Inspired the concept of camera-assisted notch awareness.
- **[Apple Dynamic Island](https://developer.apple.com/design/human-interface-guidelines/live-activities):** Apple's iconic iPhone Dynamic Island design language, fluid morphing squircle geometry, and Live Activity status paradigms.

---

### ⚖️ Open Source Compliance & Licensing

OpenHalo is released under the **MIT License**. Components adapted or ported from GPL-licensed projects ([Glance](https://github.com/jonathan-kosgei/glance) and [Atoll](https://github.com/Ebullioscopic/Atoll)) retain their original copyright notices and license headers within their respective directories (`Sources/OpenHalo/Glance/` and `Sources/OpenHalo/Atoll/`).

We extend our sincere thanks to all authors and contributors for their outstanding work and dedication to the open-source ecosystem.
