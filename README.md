# Menu2FA 🔑

**Menu2FA** is a native, ultra-lightweight macOS Menu Bar 2FA Authenticator application built with pure Swift and SwiftUI. It lives strictly in your top macOS menu bar (`LSUIElement = true`), providing instant keyboard-driven access to your Two-Factor Authentication (TOTP) codes with **zero Dock clutter**, **zero network tracking**, and **strictly zero macOS Keychain UI permission prompts**.

---

## ✨ Features

- 🚀 **Pure Menu Bar Experience (`LSUIElement`):** Lives unobtrusively in your status bar. No dock icon, no background clutter.
- 🎨 **Maccy-Style Dropdown & Undockable Window Mode:**
  - Fast native dropdown menu with keyboard shortcuts (`⌘1`, `⌘2`, ..., `⌘9`).
  - Undock into a standalone floating window (`⌘U`) with optional **Always-On-Top** pinning (`⌘T`).
  - Instant live search filtering by account name or issuer.
- 🔒 **Zero Keychain UI Prompts & Encrypted Local Vault:**
  - Authenticated **AES-256-GCM encryption** via Apple's native `CryptoKit`.
  - Dedicated 256-bit symmetric encryption key stored locally with strict `0600` (`-rw-------`) POSIX permissions.
  - Complete elimination of macOS Security framework / Keychain prompt spam.
  - Self-healing permission checks and automatic corrupted vault backup recovery.
- 🎛 **Multi-Algorithm RFC 6238 TOTP Engine:**
  - Supports **HMAC-SHA1**, **HMAC-SHA256**, and **HMAC-SHA512**.
  - Custom code lengths (**6, 7, or 8 digits**) and custom refresh periods (**15s, 30s, 60s**).
- ⚡ **Smart Single & Multi-Account Parser:**
  - Accepts single or multi-line pastes of:
    - Tab-separated: `HXDMVJECJJWSRB3H\tuser@example.com`
    - Space-separated: `user@example.com HXDMVJECJJWSRB3H`
    - Service prefix: `GitHub: user@example.com HXDMVJECJJWSRB3H`
    - Full standard URIs: `otpauth://totp/Google:user@example.com?secret=HXDMVJECJJWSRB3H&issuer=Google&algorithm=SHA256&digits=8&period=60`
  - Automatic normalization of Unicode dashes, thin spaces, zero-width spaces, and Base32 padding.
  - Intelligent 3-tier deduplication (by secret key, by service + name, and case-insensitive).
- ⏳ **Live Countdown Ring & 1-Click Instant Copy:**
  - Real-time animated countdown ring indicating remaining token validity seconds.
  - Click any account row or press its shortcut to instantly copy the code to your clipboard with visual confirmation.
- ⚙️ **Preferences & Customization:**
  - Menu Bar Style: **Icon Only (Compact)** or **Icon + Text ("2FA")**.
  - Sorting: Newest first or alphabetical.
  - **Launch at Login** support via macOS `SMAppService`.
- 📦 **Encrypted Vault Backup & Restore:**
  - Export and import your complete 2FA account database as JSON backups anytime.
- ⚡ **Native Apple Silicon & Intel Support:**
  - Compiled natively for Apple Silicon (M1/M2/M3/M4) and Intel Macs (macOS 12.0+).

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| `⌘1` – `⌘9` | **Quick Copy** | Instantly copy OTP for account 1 through 9 |
| `⌘N` | **Add Account** | Open the Add Account window |
| `⌘,` | **Preferences** | Open the Settings / Preferences window |
| `⌘U` | **Toggle Undock** | Detach the popover into a floating window |
| `⌘T` | **Always on Top** | Pin floating window above all other apps |
| `Esc` | **Close / Clear** | Clear search filter or close the menu |
| `⌘Q` | **Quit** | Terminate Menu2FA |

---

## 💻 System Requirements

- **Operating System:** macOS 12.0 (Monterey) or later
- **Architecture:** Apple Silicon (M1 / M2 / M3 / M4) or Intel (x86_64)
- **Tools:** Xcode Command Line Tools (`xcode-select --install`) for building from source

---

## 🚀 Installation & Setup

### Option 1: Fast 1-Line Installer (Recommended)

Clone the repository and run `install.sh`:

```bash
git clone https://github.com/your-username/menu2fa.git
cd menu2fa
chmod +x install.sh build.sh
./install.sh
```

This will run the full unit test suite, compile the binary for Apple Silicon, package it into `/Applications/Menu2FA.app`, sign it ad-hoc, and launch the application into your menu bar.

---

### Option 2: Build from Source (`build.sh`)

You can build and package `Menu2FA.app` directly using the provided build script:

```bash
chmod +x build.sh
./build.sh
```

The compiled application will be generated in `build/Menu2FA.app` and automatically installed to `/Applications/Menu2FA.app`.

---

## 🛡️ Fix "Menu2FA Cannot Be Opened" / Gatekeeper on Other Macs

When moving `Menu2FA.app` between Macs (via AirDrop, USB, Slack, or ZIP), macOS attaches Gatekeeper quarantine attributes.

Run this 1-line command in Terminal on the target Mac:

```bash
chmod +x /Applications/Menu2FA.app/Contents/MacOS/Menu2FA && xattr -cr /Applications/Menu2FA.app && codesign --force --deep --sign - /Applications/Menu2FA.app
```

This automatically:
1. Restores executable permissions on the binary.
2. Clears macOS Gatekeeper quarantine (`xattr -cr`).
3. Ad-hoc signs the application for that specific machine.

Then launch the app with:
```bash
open /Applications/Menu2FA.app
```

---

## 🔒 Security & Privacy Architecture

- **Zero Keychain Prompt Annoyance:** Unlike standard Keychain-backed utilities that trigger system password prompts or Touch ID dialogues on every app access or update, Menu2FA uses a local application-support vault.
- **AES-256-GCM Vault Encryption:**
  - Secrets are encrypted with CryptoKit `AES.GCM` authenticated encryption.
  - A unique 256-bit symmetric key is stored at `~/Library/Application Support/Menu2FA/vault.key`.
  - Vault and key files are enforced with POSIX `0600` permissions (`-rw-------`), accessible strictly by your user account.
- **Zero Network Access:** Menu2FA has no network permissions, no telemetry, and no third-party tracking. All TOTP generation happens 100% offline on your device.
- **Corrupted Vault Recovery:** If a file write is interrupted, Menu2FA creates a timestamped recovery backup (`vault.json.corrupted.<timestamp>`) and reinitializes safely without losing app functionality.

---

## 🧪 Running Automated Unit Tests

Menu2FA includes an extensive test suite verifying:
- **54 RFC 6238 Test Vectors** (SHA1, SHA256, SHA512 across timestamps up to 2,000,000,000s).
- **CryptoKit AES-256-GCM Encryption / Decryption** roundtrips and tamper-detection.
- **POSIX `0600` File Permissions** enforcement and automatic self-healing.
- **SmartParser edge cases**, URI percent-decoding, and multi-line parsing.
- **Account deduplication** and JSON vault import/export.

To run the test suite:

```bash
swiftc -O -target arm64-apple-macosx12.0 -sdk $(xcrun --show-sdk-path) \
    TOTPGenerator.swift \
    SmartParser.swift \
    TOTPEntry.swift \
    AccountStore.swift \
    TestRunner.swift \
    -o build/TestRunner
./build/TestRunner
```

---

## 📁 Project Architecture

```
menu2fa/
├── AccountListView.swift       # SwiftUI account list container with search filtering
├── AccountStore.swift          # Reactive store, AES-256-GCM vault manager & deduplication
├── AddAccountWindowView.swift  # Floating window for single / multi-account manual addition
├── AppDelegate.swift           # NSStatusItem controller, popover & detached window manager
├── AppIcon.icns                # Application icon
├── AutoLaunchManager.swift     # SMAppService helper for Launch at Login
├── EditableControls.swift      # Custom AppKit-backed text controls for reliable copy/paste
├── HomePopoverView.swift       # Main SwiftUI popover interface
├── Info.plist                  # Application bundle configuration (LSUIElement = true)
├── MenuHeaderView.swift        # Top header with search bar, undock, add & settings actions
├── MenuRowView.swift           # Interactive account row with countdown timer & copy action
├── README.md                   # Comprehensive documentation
├── SettingsWindowView.swift    # Preferences window (appearance, auto-launch, import/export)
├── SmartParser.swift           # Robust Base32, URI & multi-format parser
├── TOTPEntry.swift             # Data models for accounts, export items, and algorithms
├── TOTPGenerator.swift         # RFC 6238 TOTP computation (SHA1, SHA256, SHA512)
├── TestRunner.swift            # 100+ assertion automated verification suite
├── build.sh                    # Automated build, test, and install script
└── install.sh                  # Quick one-step installer script
```

---

## 📄 License

Distributed under the **MIT License**. Free and open-source for personal and commercial use.
