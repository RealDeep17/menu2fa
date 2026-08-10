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
        chmod +x "$APP_TARGET/Contents/MacOS/Menu2FA"
        xattr -cr "$APP_TARGET" || true
        codesign --force --deep --sign - "$APP_TARGET"
        echo "✅ Permissions & Ad-hoc signature updated for $APP_TARGET!"
    else
        echo "❌ Menu2FA.app not found in /Applications. Please copy Menu2FA.app to /Applications first."
        exit 1
    fi
fi

# Launch app
open "$APP_TARGET"
echo "🎉 Menu2FA is now running in your top menu bar!"
