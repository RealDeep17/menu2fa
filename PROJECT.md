# Project: Menu2FA Audit, Hardening, Encryption, and Testing

## Architecture
- Native macOS menu bar 2FA authenticator application written in Swift (AppKit + SwiftUI).
- Persistence: Encrypted local vault (`vault.json`) using CryptoKit AES-256-GCM with local 256-bit key storage (`vault.key`, POSIX 0600 file permissions). ZERO macOS Keychain UI prompts.
- Core Business Logic: `TOTPGenerator` (RFC 6238 TOTP with SHA1/SHA256/SHA512 support), `SmartParser` (OTPAuth URI & secret parsing), `AccountStore` (Vault state management & deduplication).
- View Hierarchy: `AppDelegate` (menu bar status item & window manager), `HomePopoverView` (main popover UI), `AccountListView`, `MenuHeaderView`, `MenuRowView`, `AddAccountWindowView`, `SettingsWindowView`, `EditableControls`.
- Compilation & Testing: Standalone shell script `./build.sh` building swift files and running `TestRunner`.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Codebase Audit & Dead Code Removal | Identify and remove obsolete files (`PopoverView.swift`, `SettingsView.swift`, `AccountRowView.swift`, `AddAccountView.swift`), dead imports (`CoreImage`), obsolete QR documentation in `README.md` | M1 | R1, Survey 1 |
| 2 | Memory Leak & Observer Hardening | Fix unhandled observers (`SortOrderSettingChanged`), optimize per-row Combine timers in `MenuRowView`, ensure `[weak self]` safety in event monitors | M1 | R1, Survey 1 |
| 3 | Secure Key Management (Zero Keychain Prompts) | Store 256-bit symmetric key locally at `~/Library/Application Support/Menu2FA/vault.key` with POSIX `0600` permissions without using Keychain (`SecItem`) dialogs | M2 | R2, Survey 2 |
| 4 | CryptoKit AES-256-GCM Vault Storage | Encrypt/decrypt `vault.json` payload using Apple CryptoKit AES.GCM, sealed box wrapper, atomic writes, `0600` permissions, legacy migration & corrupted vault recovery | M2 | R2, Survey 2 |
| 5 | RFC 6238 TOTP Engine Hardening | Extend `TOTPGenerator` to support HMAC-SHA1, HMAC-SHA256, HMAC-SHA512, 6/7/8 digits, custom time periods (e.g. 30s, 60s) | M3 | R3, Survey 3 |
| 6 | SmartParser URI & Secret Hardening | Parse `algorithm`, `digits`, `period` from `otpauth://` URIs; handle percent-encoding, whitespace normalization, and edge case manual secrets | M3 | R3, Survey 3 |
| 7 | AccountStore & Window Hardening | Account deduplication, atomic save operations, safe popover vs detached window management, thread-safe access | M3 | R3, Survey 3 |
| 8 | QR Code Feature Exclusion | Verify complete removal of QR scanning code, references, or camera dependencies across codebase | M3 | R3, Survey 3 |
| 9 | Comprehensive Test Suite Expansion | Expand `TestRunner.swift` with tests for RFC 6238 TOTP, AES-256-GCM encryption roundtrips, SmartParser edge cases, serialization, deduplication | M4 | R4, Survey 3 |
| 10| Clean Build Verification | Ensure `./build.sh` compiles and executes all unit tests with 0 errors | M4 | R4 |
| 11| Git Checkpoint & Commit | Commit all improvements with clear, descriptive git commit messages | M5 | R5 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Codebase Audit & Dead Code Removal | Remove 4 legacy views, clean dead imports, fix observer leaks & timer handling | none | DONE |
| M2 | Secure Encrypted Local Vault | Implement CryptoKit AES-256-GCM vault, local key manager (0600), zero Keychain dialogs, migration & recovery | M1 | DONE |
| M3 | Component Hardening & Sanitization | Extend TOTPGenerator (SHA1/256/512), harden SmartParser & AccountStore deduplication, sanitize QR references | M1, M2 | DONE |
| M4 | Test Suite Expansion & Build Verification | Expand TestRunner.swift with full assertion matrix; verify clean build via ./build.sh | M1, M2, M3 | DONE |
| M5 | Git Commit & Checkpoint | Create clean git commits capturing all changes with detailed messages | M1, M2, M3, M4 | DONE |

## Interface Contracts
### `VaultKeyManager` & `VaultEncryptor` (M2)
- Key storage path: `~/Library/Application Support/Menu2FA/vault.key` (POSIX permissions `0600`).
- Envelope structure:
  ```swift
  struct VaultEnvelope: Codable {
      let version: Int
      let combinedData: String // Base64-encoded CryptoKit AES.GCM.SealedBox.combined
  }
  ```
- Methods:
  - `VaultKeyManager.getOrCreateKey() throws -> SymmetricKey`
  - `VaultEncryptor.encrypt(data: Data, key: SymmetricKey) throws -> Data`
  - `VaultEncryptor.decrypt(envelopeData: Data, key: SymmetricKey) throws -> Data`

### `TOTPGenerator` Extensions (M3)
- Supported Algorithms: `.sha1`, `.sha256`, `.sha512`
- Method signature:
  `static func generateTOTP(secret: String, algorithm: OTPAlgorithm = .sha1, digits: Int = 6, period: TimeInterval = 30, time: Date = Date()) -> String?`

### `SmartParser` Extensions (M3)
- Result structure:
  `struct ParsedOTPAccount { var label: String; var issuer: String; var secret: String; var algorithm: OTPAlgorithm; var digits: Int; var period: TimeInterval }`
- Method signature:
  `static func parse(_ input: String) -> ParsedOTPAccount?`

## Code Layout
- Active compilation target files:
  - `AppDelegate.swift`
  - `AccountStore.swift`
  - `TOTPGenerator.swift`
  - `TOTPEntry.swift`
  - `SmartParser.swift`
  - `HomePopoverView.swift`
  - `AccountListView.swift`
  - `MenuHeaderView.swift`
  - `MenuRowView.swift`
  - `AddAccountWindowView.swift`
  - `SettingsWindowView.swift`
  - `EditableControls.swift`
  - `AutoLaunchManager.swift`
  - `TestRunner.swift`
- Removed legacy view files (M1):
  - `PopoverView.swift` (DELETED)
  - `SettingsView.swift` (DELETED)
  - `AccountRowView.swift` (DELETED)
  - `AddAccountView.swift` (DELETED)
