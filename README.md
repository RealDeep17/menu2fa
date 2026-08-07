# Menu2FA 🔑

**Menu2FA** is a native, lightweight macOS Menu Bar 2FA Authenticator application built with pure Swift and SwiftUI. It runs **strictly in your top macOS menu bar** (status bar) with `LSUIElement = true` (no dock icon, no desktop window clutter).

---

## Features

- 🚀 **Pure Menu Bar App:** Lives exclusively in your macOS status bar (`LSUIElement`).
- ⚡ **Smart Single-Line Parser:** Accepts single-line pastes of:
  - `4DM2M47UQISBDUHV\tvasilolein54@gmail.com`
  - `vasilolein54@gmail.com 4DM2M47UQISBDUHV`
  - `4DM2M47UQISBDUHV vasilolein54@gmail.com`
  - Standard `otpauth://totp/...` URIs.
- 🔒 **Native Security:** Base32 secrets are securely stored in the **macOS Keychain** using Apple's Security framework.
- ⏳ **Visual 30s Countdown:** Real-time countdown progress bar indicating the remaining validity seconds of TOTP codes.
- 📋 **1-Click Copy:** Click any account row to instantly copy the 6-digit code to your clipboard with a "Copied!" notification toast.
- 🔍 **Real-Time Search:** Instantly filter your 2FA accounts by name or issuer.
- 📦 **Encrypted JSON Vault Backup:** Import and export your accounts as JSON backups at any time.

---

## Installation & Build

To build the standalone `.app` bundle:

```bash
chmod +x build.sh
./build.sh
```

The compiled application bundle will be generated at:
`build/Menu2FA.app`

### Running the App:
```bash
open build/Menu2FA.app
```

---

## How to Add 2FA Accounts

1. Click the **lock/shield icon** in your macOS top menu bar.
2. Click the **`+`** icon in the top right of the popover.
3. In the **Smart Input** box, paste your string in any format:
   - `4DM2M47UQISBDUHV\tvasilolein54@gmail.com`
   - `vasilolein54@gmail.com 4DM2M47UQISBDUHV`
   - `4DM2M47UQISBDUHV`
4. The live preview will automatically validate the secret and generate the 6-digit TOTP code.
5. Click **Save Account**.
