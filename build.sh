#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Menu2FA.app"
CONTENTS_DIR="$APP_DIR/Contents"
MacOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building Menu2FA Universal macOS App (Apple Silicon + Intel)..."

mkdir -p "$MacOS_DIR" "$RESOURCES_DIR" "$BUILD_DIR/bin"

# Copy Info.plist and AppIcon.icns
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

SWIFT_SOURCES=(
    "$PROJECT_DIR/TOTPGenerator.swift"
    "$PROJECT_DIR/SmartParser.swift"
    "$PROJECT_DIR/KeychainManager.swift"
    "$PROJECT_DIR/AutoLaunchManager.swift"
    "$PROJECT_DIR/QRCodeScanner.swift"
    "$PROJECT_DIR/TOTPEntry.swift"
    "$PROJECT_DIR/AccountStore.swift"
    "$PROJECT_DIR/MenuHeaderView.swift"
    "$PROJECT_DIR/MenuRowView.swift"
    "$PROJECT_DIR/AddAccountWindowView.swift"
    "$PROJECT_DIR/SettingsWindowView.swift"
    "$PROJECT_DIR/AppDelegate.swift"
)

SDK_PATH=$(xcrun --show-sdk-path)

echo "  -> Compiling arm64 (Apple Silicon)..."
swiftc -O -target arm64-apple-macosx12.0 -sdk "$SDK_PATH" -parse-as-library "${SWIFT_SOURCES[@]}" -o "$BUILD_DIR/bin/Menu2FA_arm64"

echo "  -> Compiling x86_64 (Intel)..."
swiftc -O -target x86_64-apple-macosx12.0 -sdk "$SDK_PATH" -parse-as-library "${SWIFT_SOURCES[@]}" -o "$BUILD_DIR/bin/Menu2FA_x86_64"

echo "  -> Combining into Universal Binary..."
lipo -create "$BUILD_DIR/bin/Menu2FA_arm64" "$BUILD_DIR/bin/Menu2FA_x86_64" -output "$MacOS_DIR/Menu2FA"

# Code sign ad-hoc and clear quarantine attributes
xattr -cr "$APP_DIR" || true
codesign --force --deep --sign - "$APP_DIR"

# Copy to /Applications
echo "📦 Installing Menu2FA.app to /Applications..."
rm -rf "/Applications/Menu2FA.app" || true
cp -R "$APP_DIR" "/Applications/Menu2FA.app"
xattr -cr "/Applications/Menu2FA.app" || true

echo "✅ Successfully built Universal Menu2FA.app (arm64 + x86_64)!"
