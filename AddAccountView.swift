import SwiftUI
import AppKit

struct AddAccountView: View {
    @ObservedObject var store: AccountStore
    @Binding var isPresented: Bool

    @State private var smartInput: String = ""
    @State private var name: String = ""
    @State private var issuer: String = "General"
    @State private var secret: String = ""

    @State private var previewOTP: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Add 2FA Account")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Smart Input Box
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Input (Name + Secret, Secret + Name, or URI):")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Paste: 4DM2M47UQISBDUHV vasilolein54@gmail.com", text: $smartInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onChange(of: smartInput) { newValue in
                            parseInput(newValue)
                        }

                    Button("Paste") {
                        if let clipboard = NSPasteboard.general.string(forType: .string) {
                            smartInput = clipboard
                            parseInput(clipboard)
                        }
                    }
                    .font(.system(size: 11))
                }
            }

            Divider()

            // Parsed / Editable Fields
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Account Name:")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 90, alignment: .leading)
                    TextField("e.g. vasilolein54@gmail.com", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                HStack {
                    Text("Issuer / Service:")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 90, alignment: .leading)
                    TextField("e.g. Google, GitHub", text: $issuer)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                }

                HStack {
                    Text("Secret Key:")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 90, alignment: .leading)
                    TextField("e.g. 4DM2M47UQISBDUHV", text: $secret)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .onChange(of: secret) { newValue in
                            updatePreview(secret: newValue)
                        }
                }
            }

            // Live OTP Code Preview
            if let preview = previewOTP {
                HStack {
                    Text("Live Code Preview:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(preview)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
                .padding(8)
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
                Button("Cancel") {
                    isPresented = false
                }
                .font(.system(size: 12))

                Button("Save Account") {
                    saveAccount()
                }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.borderedProminent)
                .disabled(secret.trimmingCharacters(in: .whitespaces).isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func parseInput(_ text: String) {
        if let parsed = SmartParser.parse(text) {
            self.name = parsed.name
            self.issuer = parsed.issuer
            self.secret = parsed.secret
            self.errorMessage = nil
            updatePreview(secret: parsed.secret)
        } else {
            updatePreview(secret: secret)
        }
    }

    private func updatePreview(secret: String) {
        let clean = SmartParser.cleanSecret(secret)
        if SmartParser.isBase32Secret(clean), let code = TOTPGenerator.generateOTP(secret: clean) {
            self.previewOTP = code
            self.errorMessage = nil
        } else {
            self.previewOTP = nil
            if !secret.isEmpty {
                self.errorMessage = "Invalid Base32 secret key"
            }
        }
    }

    private func saveAccount() {
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

        if store.addAccount(name: cleanName, issuer: cleanIssuer.isEmpty ? "General" : cleanIssuer, secret: cleanSecret) {
            isPresented = false
        } else {
            errorMessage = "Failed to save secret to Keychain"
        }
    }
}
