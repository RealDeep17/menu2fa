#!/bin/bash
set -e

echo "🚀 Installing Menu2FA on your Mac..."

# Target location
APP_TARGET="/Applications/Menu2FA.app"

# If repository or source exists, compile locally
if [ -f "./build.sh" ]; then
    chmod +x ./build.sh
    ./build.sh
else
    # Fix executable permissions, clear quarantine, and re-sign ad-hoc for this Mac
    if [ -d "$APP_TARGET" ]; then
        chmod -R 755 "$APP_TARGET"
        xattr -dr com.apple.quarantine "$APP_TARGET" 2>/dev/null || true
        xattr -cr "$APP_TARGET" 2>/dev/null || true
        codesign --force --deep --sign - "$APP_TARGET"
        codesign --verify --deep --strict "$APP_TARGET"
        echo "✅ Permissions, quarantine removal, & signature verified for $APP_TARGET!"
    else
        echo "❌ Menu2FA.app not found in /Applications. Please copy Menu2FA.app to /Applications first."
        exit 1
    fi
fi

# Launch app
open "$APP_TARGET"
echo "🎉 Menu2FA is now running in your top menu bar!"
