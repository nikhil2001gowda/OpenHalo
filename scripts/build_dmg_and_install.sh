#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
APP_NAME="OpenHalo.app"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}"
DMG_PATH="${BUILD_DIR}/OpenHalo.dmg"
DMG_TEMP_DIR="${BUILD_DIR}/dmg_temp"

echo "=========================================="
echo "🚀 Building OpenHalo 4.0 Release..."
echo "=========================================="

cd "${PROJECT_DIR}"
swift build -c release

echo "📦 Packaging ${APP_NAME}..."
rm -rf "${APP_BUNDLE}"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

cp "${PROJECT_DIR}/.build/release/OpenHalo" "${MACOS_DIR}/OpenHalo"
chmod +x "${MACOS_DIR}/OpenHalo"
if [ -d "${PROJECT_DIR}/Resources" ]; then
    cp -R "${PROJECT_DIR}/Resources/"* "${RESOURCES_DIR}/"
fi

cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OpenHalo</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>in.mewlabs.openhalo</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenHalo</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>4.0.0</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSAppleEventsUsageDescription</key>
    <string>OpenHalo interacts with Apple Music and Spotify to display now playing information and transport controls.</string>
    <key>NSCameraUsageDescription</key>
    <string>OpenHalo uses your camera strictly when you open the Mirror tab for a quick appearance check before video calls, or for 5-second lock-screen face assist.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>OpenHalo displays your upcoming schedule and next meeting countdown directly in the dynamic island.</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>OpenHalo displays your upcoming schedule and next meeting countdown directly in the dynamic island.</string>
</dict>
</plist>
EOF

echo "🔏 Signing ${APP_NAME} with stable designated requirement..."
codesign --force --deep -s - --requirements '=designated => identifier "in.mewlabs.openhalo"' "${APP_BUNDLE}" 2>/dev/null || true

# 1. Install directly to /Applications (or ~/Applications)
TARGET_APP="/Applications/${APP_NAME}"
if [ ! -w "/Applications" ]; then
    TARGET_APP="${HOME}/Applications/${APP_NAME}"
    mkdir -p "${HOME}/Applications"
fi

echo "📥 Installing to ${TARGET_APP}..."
# Stop existing running instance
killall OpenHalo 2>/dev/null || true
sleep 0.5

rm -rf "${TARGET_APP}"
cp -R "${APP_BUNDLE}" "${TARGET_APP}"
codesign --force --deep -s - --requirements '=designated => identifier "in.mewlabs.openhalo"' "${TARGET_APP}" 2>/dev/null || true

# 2. Generate OpenHalo.dmg
echo "💿 Creating standalone OpenHalo.dmg..."
rm -rf "${DMG_TEMP_DIR}" "${DMG_PATH}"
mkdir -p "${DMG_TEMP_DIR}"

cp -R "${APP_BUNDLE}" "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

hdiutil create \
    -volname "OpenHalo" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}" >/dev/null

rm -rf "${DMG_TEMP_DIR}"

echo "=========================================="
echo "🎉 SUCCESS: OpenHalo 4.0 Built & Installed!"
echo "📁 Installed App: ${TARGET_APP}"
echo "💿 Distribution DMG: ${DMG_PATH}"
echo "=========================================="

# Launch the newly installed application
echo "🚀 Launching ${TARGET_APP}..."
open "${TARGET_APP}"

echo "✨ OpenHalo is now live on your Mac!"

