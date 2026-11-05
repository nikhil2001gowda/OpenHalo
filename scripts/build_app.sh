#!/bin/bash
set -e

echo "🚀 Building OpenHalo Release Binary..."
swift build -c release

APP_DIR="build/OpenHalo.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Packaging ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp ".build/release/OpenHalo" "${MACOS_DIR}/OpenHalo"
chmod +x "${MACOS_DIR}/OpenHalo"

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OpenHalo</string>
    <key>CFBundleIdentifier</key>
    <string>com.openhalo.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenHalo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppleEventsUsageDescription</key>
    <string>OpenHalo interacts with Apple Music and Spotify to display now playing information and transport controls.</string>
    <key>NSCameraUsageDescription</key>
    <string>OpenHalo uses your camera strictly when you open the Mirror tab for a quick appearance check before video calls.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>OpenHalo displays your upcoming schedule and next meeting countdown directly in the dynamic island.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>OpenHalo displays your upcoming schedule and next meeting countdown directly in the dynamic island.</string>
</dict>
</plist>
EOF

echo "🔏 Ad-hoc codesigning OpenHalo.app..."
codesign --force --deep -s - "${APP_DIR}" 2>/dev/null || true

echo "✅ OpenHalo.app successfully created at ${APP_DIR}!"

