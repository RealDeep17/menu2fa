import SwiftUI
import AppKit

struct AddAccountWindowView: View {
    @ObservedObject var store: AccountStore
    let onClose: () -> Void

    @State private var selectedTab: Int = 0 // 0: Manual Entry, 1: Smart / Bulk Paste
    
    // Single Account State
    @State private var name: String = ""
    @State private var issuer: String = ""
    @State private var secret: String = ""
    @State private var algorithm: OTPAlgorithm = .sha1
    @State private var digits: Int = 6
    @State private var period: TimeInterval = 30.0
    
    // Bulk / Smart Input State
    @State private var smartInput: String = ""
    @State private var parsedAccounts: [Parsed2FA] = []
    
    // Common State
    @State private var previewOTP: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header & Mode Selector
            HStack {
                Text("Add 2FA Account(s)")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }

            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("Single Account").tag(0)
                Text("Smart / Bulk Paste").tag(1)
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                // MARK: - Single Account Manual Entry
                VStack(alignment: .leading, spacing: 10) {
                    // Account Name
                    HStack {
                        Text("Account Name:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 95, alignment: .leading)
                        EditableTextField(text: $name, placeholder: "e.g. user@example.com")
                            .frame(height: 22)
                    }

                    // Issuer / Service
                    HStack {
                        Text("Issuer / Service:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 95, alignment: .leading)
                        EditableTextField(text: $issuer, placeholder: "e.g. Google, GitHub, AWS")
                            .frame(height: 22)
                    }

                    // Secret Key with dedicated Paste button
                    HStack {
                        Text("Secret Key:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 95, alignment: .leading)
                        EditableTextField(text: $secret, placeholder: "e.g. HXDMVJECJJWSRB3H", isMonospaced: true, onChange: { newValue in
                            handleSecretFieldChange(newValue)
                        })
                        .frame(height: 22)

                        Button(action: pasteIntoSecretKey) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste")
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Text("Tip: You can paste a raw secret, an otpauth:// URI, or 'name secret' text directly.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                // Live OTP Code Preview
                if let preview = previewOTP {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Live Code Preview:")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(preview)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(issuer.isEmpty ? "General" : issuer)")
                                .font(.system(size: 11, weight: .semibold))
                            Text("\(name.isEmpty ? "Account" : name)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
            } else {
                // MARK: - Smart / Bulk Paste
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Paste URIs or multiple lines (Secret+Name, Name+Secret, etc.):")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: pasteIntoSmartEditor) {
                            HStack(spacing: 3) {
                                Image(systemName: "doc.on.clipboard")
                                Text("Paste Clipboard")
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    EditableTextEditor(text: $smartInput, onChange: { newValue in
                        parseSmartInput(newValue)
                    })
                    .frame(height: 75)

                    if !parsedAccounts.isEmpty {
                        Text("Found \(parsedAccounts.count) valid account\(parsedAccounts.count == 1 ? "" : "s"):")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(0..<parsedAccounts.count, id: \.self) { idx in
                                    let item = parsedAccounts[idx]
                                    HStack {
                                        Text("\(idx + 1). \(item.issuer.isEmpty ? "" : "[\(item.issuer)] ")\(item.name)")
                                            .font(.system(size: 11, weight: .semibold))
                                        Spacer()
                                        Text(item.secret)
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(height: 60)
                    }
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            Spacer(minLength: 0)

            // Action Buttons
            HStack {
                Spacer()
                Button("Cancel", action: onClose)
                    .font(.system(size: 12))

                if selectedTab == 0 {
                    Button("Save Account") {
                        saveSingleAccount()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .disabled(secret.trimmingCharacters(in: .whitespaces).isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
                } else {
                    Button(parsedAccounts.count > 1 ? "Save \(parsedAccounts.count) Accounts" : "Save Account") {
                        saveBulkAccounts()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedAccounts.isEmpty)
                }
            }
        }
        .padding(16)
        .frame(width: 410, height: 350)
    }

    // MARK: - Secret Key Field Handling
    private func pasteIntoSecretKey() {
        guard let clipboard = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !clipboard.isEmpty else { return }
        handleSecretFieldChange(clipboard)
    }

    private func handleSecretFieldChange(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it's a URI or multi-part format pasted into Secret Key, auto-parse everything
        if trimmed.lowercased().hasPrefix("otpauth://") || trimmed.contains("\t") {
            if let parsed = SmartParser.parse(trimmed) {
                if self.name.isEmpty { self.name = parsed.name }
                if self.issuer.isEmpty { self.issuer = parsed.issuer }
                self.secret = parsed.secret
                self.algorithm = parsed.algorithm
                self.digits = parsed.digits
                self.period = parsed.period
                updateSinglePreview(secret: parsed.secret)
                return
            }
        }

        self.secret = trimmed
        updateSinglePreview(secret: trimmed)
    }

    private func updateSinglePreview(secret: String) {
        let clean = SmartParser.cleanSecret(secret)
        if SmartParser.isBase32Secret(clean),
           let code = TOTPGenerator.generateTOTP(secret: clean, algorithm: algorithm, digits: digits, period: period) {
            self.previewOTP = code
            self.errorMessage = nil
        } else {
            self.previewOTP = nil
            if !secret.trimmingCharacters(in: .whitespaces).isEmpty {
                self.errorMessage = "Secret key must be a valid Base32 string (letters A-Z, digits 2-7)"
            } else {
                self.errorMessage = nil
            }
        }
    }

    // MARK: - Smart / Bulk Paste Handling
    private func pasteIntoSmartEditor() {
        if let clipboard = NSPasteboard.general.string(forType: .string) {
            smartInput = clipboard
            parseSmartInput(clipboard)
        }
    }

    private func parseSmartInput(_ text: String) {
        let multiple = SmartParser.parseMultiple(text)
        self.parsedAccounts = multiple

        if let first = multiple.first {
            self.errorMessage = nil
            updateSinglePreview(secret: first.secret)
        } else if let single = SmartParser.parse(text) {
            self.parsedAccounts = [Parsed2FA(name: single.name, issuer: single.issuer, secret: single.secret, algorithm: single.algorithm, digits: single.digits, period: single.period)]
            self.errorMessage = nil
            updateSinglePreview(secret: single.secret)
        } else {
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.errorMessage = "Could not detect valid 2FA secrets. Please check format."
            } else {
                self.errorMessage = nil
            }
        }
    }

    // MARK: - Saving
    private func saveSingleAccount() {
        let cleanName = name.trimmingCharacters(in: .whitespaces)
        let cleanIssuer = issuer.trimmingCharacters(in: .whitespaces)
        let cleanSecret = SmartParser.cleanSecret(secret)

        guard !cleanName.isEmpty else {
            errorMessage = "Account name is required"
            return
        }

        guard SmartParser.isBase32Secret(cleanSecret) else {
            errorMessage = "Valid Base32 secret key is required (A-Z, 2-7)"
            return
        }

        if store.addAccount(
            name: cleanName,
            issuer: cleanIssuer.isEmpty ? "General" : cleanIssuer,
            secret: cleanSecret,
            algorithm: algorithm,
            digits: digits,
            period: period
        ) {
            NSSound.beep()
            onClose()
        } else {
            errorMessage = "Failed to save account"
        }
    }

    private func saveBulkAccounts() {
        var added = 0
        for item in parsedAccounts {
            if store.addAccount(
                name: item.name,
                issuer: item.issuer,
                secret: item.secret,
                algorithm: item.algorithm,
                digits: item.digits,
                period: item.period
            ) {
                added += 1
            }
        }
        if added > 0 {
            NSSound.beep()
            onClose()
        } else {
            errorMessage = "Failed to save accounts"
        }
    }
}


