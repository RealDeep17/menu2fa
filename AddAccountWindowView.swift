import SwiftUI
import AppKit

struct AddAccountWindowView: View {
    @ObservedObject var store: AccountStore
    let onClose: () -> Void

    @State private var smartInput: String = ""
    @State private var name: String = ""
    @State private var issuer: String = ""
    @State private var secret: String = ""

    @State private var parsedAccounts: [Parsed2FA] = []
    @State private var previewOTP: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Add 2FA Account(s)")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Smart Multi-line Input Box
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Input (Single or Multi-line Paste: Secret+Name+Issuer, Secret+Name, Name+Secret, URIs):")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    EditableTextEditor(text: $smartInput, onChange: { newValue in
                        parseInput(newValue)
                    })
                    .frame(height: 60)

                    VStack {
                        Button("Paste Clipboard") {
                            if let clipboard = NSPasteboard.general.string(forType: .string) {
                                smartInput = clipboard
                                parseInput(clipboard)
                            }
                        }
                        .font(.system(size: 11))
                        Spacer()
                    }
                }
            }

            Divider()

            // Multiple Accounts Summary or Single Account Editor
            if parsedAccounts.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Found \(parsedAccounts.count) valid 2FA accounts in input:")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(0..<parsedAccounts.count, id: \.self) { idx in
                                let item = parsedAccounts[idx]
                                HStack {
                                    Text("\(idx + 1). \(item.name)")
                                        .font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text(item.secret)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 80)
                }
            } else {
                // Single Account Details
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Account Name:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 90, alignment: .leading)
                        EditableTextField(text: $name, placeholder: "e.g. user@example.com")
                            .frame(height: 22)
                    }

                    HStack {
                        Text("Issuer / Service:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 90, alignment: .leading)
                        EditableTextField(text: $issuer, placeholder: "e.g. Google, GitHub")
                            .frame(height: 22)
                    }

                    HStack {
                        Text("Secret Key:")
                            .font(.system(size: 11, weight: .medium))
                            .frame(width: 90, alignment: .leading)
                        EditableTextField(text: $secret, placeholder: "e.g. HXDMVJECJJWSRB3H", isMonospaced: true, onChange: { newValue in
                            updatePreview(secret: newValue)
                        })
                        .frame(height: 22)
                    }
                }
            }

            // Live OTP Code Preview for single account
            if parsedAccounts.count <= 1, let preview = previewOTP {
                HStack {
                    Text("Live Code Preview:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(preview)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
            }

            // Action Buttons
            HStack {
                Spacer()
                Button("Cancel", action: onClose)
                    .font(.system(size: 12))

                Button(parsedAccounts.count > 1 ? "Save \(parsedAccounts.count) Accounts" : "Save Account") {
                    saveAccounts()
                }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .disabled(parsedAccounts.isEmpty && (secret.trimmingCharacters(in: .whitespaces).isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty))
            }
        }
        .padding(16)
        .frame(width: 380, height: 340)
    }

    private func parseInput(_ text: String) {
        let multiple = SmartParser.parseMultiple(text)
        self.parsedAccounts = multiple

        if let first = multiple.first {
            self.name = first.name
            self.issuer = first.issuer
            self.secret = first.secret
            self.errorMessage = nil
            updatePreview(secret: first.secret)
        } else if let single = SmartParser.parse(text) {
            self.name = single.name
            self.issuer = single.issuer
            self.secret = single.secret
            self.errorMessage = nil
            updatePreview(secret: single.secret)
        } else {
            updatePreview(secret: secret)
        }
    }

    private func updatePreview(secret: String) {
        let clean = SmartParser.cleanSecret(secret)
        let alg = parsedAccounts.first?.algorithm ?? .sha1
        let dig = parsedAccounts.first?.digits ?? 6
        let per = parsedAccounts.first?.period ?? 30.0
        if SmartParser.isBase32Secret(clean), let code = TOTPGenerator.generateTOTP(secret: clean, algorithm: alg, digits: dig, period: per) {
            self.previewOTP = code
            self.errorMessage = nil
        } else {
            self.previewOTP = nil
            if !secret.isEmpty && parsedAccounts.isEmpty {
                self.errorMessage = "Invalid Base32 secret key"
            }
        }
    }

    private func saveAccounts() {
        if parsedAccounts.count > 1 {
            var added = 0
            for item in parsedAccounts {
                if store.addAccount(name: item.name, issuer: item.issuer, secret: item.secret, algorithm: item.algorithm, digits: item.digits, period: item.period) {
                    added += 1
                }
            }
            if added > 0 {
                NSSound.beep()
                onClose()
            } else {
                errorMessage = "Failed to save accounts"
            }
        } else {
            let cleanName = name.trimmingCharacters(in: .whitespaces)
            let cleanIssuer = issuer.trimmingCharacters(in: .whitespaces)
            let cleanSecret = SmartParser.cleanSecret(secret)

            guard !cleanName.isEmpty else {
                errorMessage = "Account name is required"
                return
            }

            guard SmartParser.isBase32Secret(cleanSecret) else {
                errorMessage = "Valid Base32 secret key is required"
                return
            }

            let alg = parsedAccounts.first?.algorithm ?? .sha1
            let dig = parsedAccounts.first?.digits ?? 6
            let per = parsedAccounts.first?.period ?? 30.0

            if store.addAccount(name: cleanName, issuer: cleanIssuer.isEmpty ? "General" : cleanIssuer, secret: cleanSecret, algorithm: alg, digits: dig, period: per) {
                NSSound.beep()
                onClose()
            } else {
                errorMessage = "Failed to save secret"
            }
        }
    }
}

