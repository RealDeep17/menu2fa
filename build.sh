#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/Menu2FA.app"
CONTENTS_DIR="$APP_DIR/Contents"
MacOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building Menu2FA Apple Silicon macOS App (arm64)..."

mkdir -p "$MacOS_DIR" "$RESOURCES_DIR"

# Copy Info.plist and AppIcon.icns
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
if [ -f "$PROJECT_DIR/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Compile Swift files for Apple Silicon (arm64)
swiftc -O \
    -target arm64-apple-macosx12.0 \
    -sdk $(xcrun --show-sdk-path) \
    -parse-as-library \
    "$PROJECT_DIR/TOTPGenerator.swift" \
    "$PROJECT_DIR/SmartParser.swift" \
    "$PROJECT_DIR/KeychainManager.swift" \
    "$PROJECT_DIR/AutoLaunchManager.swift" \
    "$PROJECT_DIR/QRCodeScanner.swift" \
    "$PROJECT_DIR/TOTPEntry.swift" \
    "$PROJECT_DIR/AccountStore.swift" \
    "$PROJECT_DIR/MenuHeaderView.swift" \
    "$PROJECT_DIR/MenuRowView.swift" \
    "$PROJECT_DIR/AddAccountWindowView.swift" \
    "$PROJECT_DIR/SettingsWindowView.swift" \
    "$PROJECT_DIR/AppDelegate.swift" \
    -o "$MacOS_DIR/Menu2FA"

# Set executable permission
chmod +x "$MacOS_DIR/Menu2FA"

# Code sign ad-hoc and clear quarantine attributes
xattr -cr "$APP_DIR" || true
codesign --force --deep --sign - "$APP_DIR"

# Copy to /Applications
echo "📦 Installing Menu2FA.app to /Applications..."
rm -rf "/Applications/Menu2FA.app" || true
cp -R "$APP_DIR" "/Applications/Menu2FA.app"
chmod +x "/Applications/Menu2FA.app/Contents/MacOS/Menu2FA"
xattr -cr "/Applications/Menu2FA.app" || true
codesign --force --deep --sign - "/Applications/Menu2FA.app"

echo "✅ Successfully built Apple Silicon Menu2FA.app (arm64)!"
