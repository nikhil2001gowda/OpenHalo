# Contributing to OpenHalo

Thank you for your interest in contributing to OpenHalo! We welcome community contributions that help make OpenHalo the fastest, most beautiful, and most private Dynamic Island for macOS.

---

## Development Setup

### Prerequisites
- macOS 14.0 (Sonoma) or macOS 15.0+ (Sequoia)
- Xcode 15+ or Swift 5.9+ Command Line Tools
- Git

### Building Locally

1. **Clone the repository:**
   ```bash
   git clone https://github.com/nikhil2001gowda/OpenHalo.git
   cd OpenHalo
   ```

2. **Run automated verification tests:**
   ```bash
   swift run OpenHaloVerify
   ```

3. **Build the production application bundle:**
   ```bash
   ./scripts/build_app.sh
   open build/OpenHalo.app
   ```

---

## Architectural Principles

1. **Zero External Dependencies**: OpenHalo relies solely on standard Apple frameworks (`SwiftUI`, `AppKit`, `CoreAudio`, `IOKit`, `EventKit`, `AVFoundation`). Do not introduce third-party package dependencies.
2. **Absolute Privacy First**: Never record or buffer audio, capture keystrokes, or transmit telemetry over the network. Everything must run local and offline.
3. **Efficiency & Performance**: Battery life matters. Any background hardware polling must be suspended while the island is collapsed in its compact state.
4. **Non-Activating Windowing**: Keep the main window as a non-activating `NSPanel` so user focus is never stolen from active workflows.

---

## Submitting Pull Requests

1. Fork the repo and create your feature branch: `git checkout -b feature/amazing-feature`
2. Commit your changes with clear, descriptive messages.
3. Verify that `swift run OpenHaloVerify` and `./scripts/build_app.sh` succeed without errors or warnings.
4. Open a Pull Request on GitHub describing your motivation, changes, and screenshots/recordings if applicable.

