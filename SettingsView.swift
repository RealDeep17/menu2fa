import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var store: AccountStore
    @Binding var isPresented: Bool

    @State private var launchAtLogin: Bool = AutoLaunchManager.isEnabled
    @State private var persistSearchText: Bool = UserDefaults.standard.bool(forKey: "persistSearchText")
    @State private var importJSONText: String = ""
    @State private var statusMessage: String? = nil
    @State private var isSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Text("Settings & Preferences")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Launch at Login Toggle
            Toggle("Launch Menu2FA at Login", isOn: $launchAtLogin)
                .font(.system(size: 12, weight: .medium))
                .onChange(of: launchAtLogin) { newValue in
                    AutoLaunchManager.isEnabled = newValue
                }

            Divider()

            // Search Bar Memory / Persistence Option
            VStack(alignment: .leading, spacing: 5) {
                Text("Search Bar Memory:")
                    .font(.system(size: 11, weight: .semibold))

                Picker("", selection: $persistSearchText) {
                    Text("Keep typed search word (Persist)").tag(true)
                    Text("Reset / Clear search on open").tag(false)
                }
                .pickerStyle(.radioGroup)
                .font(.system(size: 11))
                .onChange(of: persistSearchText) { newValue in
                    UserDefaults.standard.set(newValue, forKey: "persistSearchText")
                }
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

                EditableTextEditor(text: $importJSONText)
                    .frame(height: 50)

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

                Button("Done") {
                    isPresented = false
                }
                .font(.system(size: 12))
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
