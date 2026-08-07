import SwiftUI
import AppKit

struct SettingsWindowView: View {
    @ObservedObject var store: AccountStore
    let onClose: () -> Void

    @State private var launchAtLogin: Bool = AutoLaunchManager.isEnabled
    @State private var showTextInMenuBar: Bool = UserDefaults.standard.bool(forKey: "showTextInMenuBar")
    @State private var maxVisibleAccounts: Int = UserDefaults.standard.object(forKey: "maxVisibleAccounts") != nil ? UserDefaults.standard.integer(forKey: "maxVisibleAccounts") : 7
    @State private var importJSONText: String = ""
    @State private var statusMessage: String? = nil
    @State private var isSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Menu2FA Preferences")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Menu Bar Display Style Setting
            VStack(alignment: .leading, spacing: 6) {
                Text("Menu Bar Style:")
                    .font(.system(size: 11, weight: .semibold))

                Picker("", selection: $showTextInMenuBar) {
                    Text("Icon Only (Compact - Saves space)").tag(false)
                    Text("Icon + Text ('2FA')").tag(true)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: 11))
                .onChange(of: showTextInMenuBar) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "showTextInMenuBar")
                    NotificationCenter.default.post(name: Notification.Name("StatusItemStyleChanged"), object: nil)
                }
            }

            Divider()

            // Max Accounts in Menu Setting
            HStack {
                Text("Max Accounts in Menu:")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Picker("", selection: $maxVisibleAccounts) {
                    Text("5 accounts").tag(5)
                    Text("7 accounts (Default)").tag(7)
                    Text("10 accounts").tag(10)
                    Text("15 accounts").tag(15)
                    Text("Unlimited").tag(0)
                }
                .labelsHidden()
                .font(.system(size: 11))
                .onChange(of: maxVisibleAccounts) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "maxVisibleAccounts")
                    NotificationCenter.default.post(name: Notification.Name("MaxAccountsSettingChanged"), object: nil)
                }
            }

            Divider()

            // Launch at Login Toggle
            Toggle("Launch Menu2FA at Login", isOn: $launchAtLogin)
                .font(.system(size: 12, weight: .medium))
                .onChange(of: launchAtLogin) { newValue in
                    AutoLaunchManager.isEnabled = newValue
                }

            Divider()

            // Export Vault
            VStack(alignment: .leading, spacing: 6) {
                Text("Export Backup:")
                    .font(.system(size: 11, weight: .semibold))

                Button("Export Vault to Clipboard (JSON)") {
                    if let json = store.exportVault() {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(json, forType: .string)
                        statusMessage = "Vault exported & copied to clipboard!"
                        isSuccess = true
                    } else {
                        statusMessage = "Failed to export vault."
                        isSuccess = false
                    }
                }
                .font(.system(size: 11))
            }

            Divider()

            // Import Vault
            VStack(alignment: .leading, spacing: 6) {
                Text("Import Backup (JSON):")
                    .font(.system(size: 11, weight: .semibold))

                TextEditor(text: $importJSONText)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(height: 45)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))

                Button("Import Vault") {
                    let count = store.importVault(jsonString: importJSONText)
                    if count > 0 {
                        statusMessage = "Successfully imported \(count) account(s)!"
                        isSuccess = true
                        importJSONText = ""
                    } else {
                        statusMessage = "Invalid JSON backup or no new accounts imported."
                        isSuccess = false
                    }
                }
                .font(.system(size: 11))
                .disabled(importJSONText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let message = statusMessage {
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSuccess ? .green : .red)
            }

            Divider()

            // Action Buttons: Quit App & Done
            HStack {
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                        Text("Quit Menu2FA")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Done", action: onClose)
                    .font(.system(size: 12))
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 340, height: 410)
    }
}
