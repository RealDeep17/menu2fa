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
- 📷 **Screen & Clipboard QR Scanner:** Scan 2FA QR codes directly from your display screen (`⌘S`) or copied clipboard image.
- ⏳ **Live 30s Countdown:** Real-time countdown badge indicating remaining validity seconds of TOTP codes.
- 📋 **1-Click Copy:** Click any account row to instantly copy the 6-digit code to your clipboard.
- ⚙️ **Preferences:** Toggle between **Icon Only (Compact)** or **Icon + Text ("2FA")** menu bar styles, plus Launch at Login support.
- 📦 **Vault Backup:** Import and export your accounts as JSON backups at any time.
- 💻 **Universal Binary:** Native support for both Apple Silicon (M1/M2/M3/M4) and Intel Macs.

---

## How to Fix "App Cannot Be Opened" on Other Macs

When downloading or transferring `Menu2FA.app` to another Mac, macOS Gatekeeper automatically attaches a quarantine flag because the app is open-source and free (not signed with a paid Apple Developer certificate).

### Option 1: Terminal Command (Fastest)
Run this single command on the other Mac:
```bash
xattr -cr /Applications/Menu2FA.app
```

### Option 2: Right-Click Open (No Terminal)
1. Open Finder and go to `/Applications`.
2. **Right-click (or Control-click)** on `Menu2FA.app`.
3. Click **Open** from the menu.
4. Click **Open** again in the macOS warning dialog.

---

## Build from Source

```bash
chmod +x build.sh
./build.sh
```

The Universal Binary application will be generated and installed to `/Applications/Menu2FA.app`.
