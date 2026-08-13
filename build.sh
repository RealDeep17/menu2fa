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

echo "🧪 Running Unit Test Suite..."
swiftc -O -target arm64-apple-macosx12.0 -sdk $(xcrun --show-sdk-path) \
    "$PROJECT_DIR/TOTPGenerator.swift" \
    "$PROJECT_DIR/SmartParser.swift" \
    "$PROJECT_DIR/TOTPEntry.swift" \
    "$PROJECT_DIR/AccountStore.swift" \
    "$PROJECT_DIR/TestRunner.swift" \
    -o "$BUILD_DIR/TestRunner"
"$BUILD_DIR/TestRunner"

# Compile Swift files for Apple Silicon (arm64)
swiftc -O \
    -target arm64-apple-macosx12.0 \
    -sdk $(xcrun --show-sdk-path) \
    -parse-as-library \
    "$PROJECT_DIR/TOTPGenerator.swift" \
    "$PROJECT_DIR/SmartParser.swift" \
    "$PROJECT_DIR/AutoLaunchManager.swift" \
    "$PROJECT_DIR/TOTPEntry.swift" \
    "$PROJECT_DIR/AccountStore.swift" \
    "$PROJECT_DIR/EditableControls.swift" \
    "$PROJECT_DIR/MenuHeaderView.swift" \
    "$PROJECT_DIR/MenuRowView.swift" \
    "$PROJECT_DIR/AccountListView.swift" \
    "$PROJECT_DIR/HomePopoverView.swift" \
    "$PROJECT_DIR/AddAccountWindowView.swift" \
    "$PROJECT_DIR/SettingsWindowView.swift" \
    "$PROJECT_DIR/AppDelegate.swift" \
    -o "$MacOS_DIR/Menu2FA"

# Set recursive permissions
echo "🔒 Setting permissions (chmod -R 755)..."
chmod -R 755 "$APP_DIR"

# Strip quarantine attributes
echo "🧹 Removing quarantine attributes (xattr)..."
xattr -dr com.apple.quarantine "$APP_DIR" 2>/dev/null || true
xattr -cr "$APP_DIR" 2>/dev/null || true

# Code sign ad-hoc
echo "✍️ Deep ad-hoc code signing (codesign --force --deep --sign -)..."
codesign --force --deep --sign - "$APP_DIR"

# Verify code signature
echo "🔍 Verifying signature (codesign --verify --deep --strict)..."
codesign --verify --deep --strict "$APP_DIR"

# Package distribution archive using ditto
echo "📦 Packaging distribution zip with ditto..."
ditto -c -k --keepParent "$APP_DIR" "$BUILD_DIR/Menu2FA.zip"

# Copy to /Applications
echo "🚀 Installing Menu2FA.app to /Applications..."
rm -rf "/Applications/Menu2FA.app" || true
cp -R "$APP_DIR" "/Applications/Menu2FA.app"
chmod -R 755 "/Applications/Menu2FA.app"
xattr -dr com.apple.quarantine "/Applications/Menu2FA.app" 2>/dev/null || true
xattr -cr "/Applications/Menu2FA.app" 2>/dev/null || true
codesign --force --deep --sign - "/Applications/Menu2FA.app"
codesign --verify --deep --strict "/Applications/Menu2FA.app"

echo "✅ Successfully built, signed, verified, and packaged Menu2FA.app (arm64)!"
echo "   App Location: /Applications/Menu2FA.app"
echo "   Zip Package:  $BUILD_DIR/Menu2FA.zip"
