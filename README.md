# Menu2FA 🔑

**Menu2FA** is a native, lightweight macOS Menu Bar 2FA Authenticator application built with pure Swift and SwiftUI. It runs **strictly in your top macOS menu bar** (status bar) with `LSUIElement = true` (no dock icon, no desktop window clutter).

---

## Features

- 🚀 **Pure Menu Bar App:** Lives exclusively in your macOS status bar (`LSUIElement`).
- 🎨 **Maccy-Style Dropdown Menu:** Clean native `NSMenu` dropdown with keyboard shortcuts (`⌘1`, `⌘2`, ...).
- ⚡ **Smart Single & Multi-Account Parser:** Accepts single or multi-line pastes of:
  - `4DM2M47UQISBDUHV\tvasilolein54@gmail.com`
  - `vasilolein54@gmail.com 4DM2M47UQISBDUHV`
  - `otpauth://totp/...` URIs.
- ⏳ **Live 30s Countdown:** Real-time countdown badge indicating remaining validity seconds of TOTP codes.
- 📋 **1-Click Copy:** Click any account row to instantly copy the 6-digit code to your clipboard.
- ⚙️ **Preferences:** Toggle between **Icon Only (Compact)** or **Icon + Text ("2FA")** menu bar styles, plus Launch at Login support.
- 📦 **Vault Backup:** Import and export your accounts as JSON backups at any time.
- ⚡ **Apple Silicon Native:** Compiled directly for M1/M2/M3/M4 Macs.

---

## Fix "Menu2FA Cannot Be Opened" on Other Macs

When transferring `Menu2FA.app` to another Mac (via AirDrop, Slack, USB, or ZIP), macOS strips binary execution permissions and attaches Gatekeeper quarantine.

### 1-Line Fix Command for Other Macs
Run this single command in Terminal on the other Mac:

```bash
chmod +x /Applications/Menu2FA.app/Contents/MacOS/Menu2FA && xattr -cr /Applications/Menu2FA.app && codesign --force --deep --sign - /Applications/Menu2FA.app
```

This performs 3 actions in 1 second:
1. `chmod +x` ➔ Restores executable permissions on the binary.
2. `xattr -cr` ➔ Clears macOS Gatekeeper quarantine.
3. `codesign --force` ➔ Signs the binary ad-hoc for that specific Mac.

Then double-click `Menu2FA.app` or run `open /Applications/Menu2FA.app`!

---

## Build from Source

```bash
chmod +x build.sh
./build.sh
```

The application will be compiled and installed to `/Applications/Menu2FA.app`.
