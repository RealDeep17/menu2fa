import SwiftUI
import AppKit

struct SettingsWindowView: View {
    @ObservedObject var store: AccountStore
    let onClose: () -> Void

    @State private var launchAtLogin: Bool = AutoLaunchManager.isEnabled
    @State private var showTextInMenuBar: Bool = UserDefaults.standard.bool(forKey: "showTextInMenuBar")
    @State private var maxVisibleAccounts: Int = UserDefaults.standard.object(forKey: "maxVisibleAccounts") != nil ? UserDefaults.standard.integer(forKey: "maxVisibleAccounts") : 10
    @State private var sortNewestFirst: Bool = UserDefaults.standard.object(forKey: "sortNewestFirst") != nil ? UserDefaults.standard.bool(forKey: "sortNewestFirst") : true
    @State private var importJSONText: String = ""
    @State private var statusMessage: String? = nil
    @State private var isSuccess = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Menu2FA Preferences")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Slim Scrollable Content View
            SleekScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    // Menu Bar Display Style
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Menu Bar Style:")
                            .font(.system(size: 10, weight: .semibold))

                        Picker("", selection: $showTextInMenuBar) {
                            Text("Icon Only (Compact)").tag(false)
                            Text("Icon + Text ('2FA')").tag(true)
                        }
                        .pickerStyle(.radioGroup)
                        .font(.system(size: 10))
                        .onChange(of: showTextInMenuBar) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "showTextInMenuBar")
                            NotificationCenter.default.post(name: Notification.Name("StatusItemStyleChanged"), object: nil)
                        }
                    }

                    Divider()

                    // Account Sort Order
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Account Sort Order:")
                            .font(.system(size: 10, weight: .semibold))

                        Picker("", selection: $sortNewestFirst) {
                            Text("Newest First (Top)").tag(true)
                            Text("Oldest First (Bottom)").tag(false)
                        }
                        .pickerStyle(.radioGroup)
                        .font(.system(size: 10))
                        .onChange(of: sortNewestFirst) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "sortNewestFirst")
                            NotificationCenter.default.post(name: Notification.Name("SortOrderSettingChanged"), object: nil)
                        }
                    }

                    Divider()

                    // Max Accounts in Menu
                    HStack {
                        Text("Max Accounts in Menu:")
                            .font(.system(size: 10, weight: .semibold))
                        Spacer()
                        Picker("", selection: $maxVisibleAccounts) {
                            Text("5").tag(5)
                            Text("10 (Default)").tag(10)
                            Text("15").tag(15)
                            Text("Unlimited").tag(0)
                        }
                        .labelsHidden()
                        .font(.system(size: 10))
                        .onChange(of: maxVisibleAccounts) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "maxVisibleAccounts")
                            NotificationCenter.default.post(name: Notification.Name("MaxAccountsSettingChanged"), object: nil)
                        }
                    }

                    Divider()

                    // Launch at Login
                    Toggle("Launch Menu2FA at Login", isOn: $launchAtLogin)
                        .font(.system(size: 11, weight: .medium))
                        .onChange(of: launchAtLogin) { newValue in
                            AutoLaunchManager.isEnabled = newValue
                        }

                    Divider()

                    // Export & Import Vault
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Backup Vault:")
                                .font(.system(size: 10, weight: .semibold))
                            Spacer()
                            Button("Export (JSON)") {
                                if let json = store.exportVault() {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(json, forType: .string)
                                    statusMessage = "Vault copied to clipboard!"
                                    isSuccess = true
                                } else {
                                    statusMessage = "Failed to export."
                                    isSuccess = false
                                }
                            }
                            .font(.system(size: 10))
                        }

                        TextEditor(text: $importJSONText)
                            .font(.system(size: 9, design: .monospaced))
                            .frame(height: 36)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3)))

                        Button("Import Backup JSON") {
                            let count = store.importVault(jsonString: importJSONText)
                            if count > 0 {
                                statusMessage = "Imported \(count) account(s)!"
                                isSuccess = true
                                importJSONText = ""
                            } else {
                                statusMessage = "Invalid JSON backup."
                                isSuccess = false
                            }
                        }
                        .font(.system(size: 10))
                        .disabled(importJSONText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    Divider()

                    // Danger Zone: Reset DB
                    HStack {
                        Text("Danger Zone:")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red)
                        Spacer()
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "trash.fill")
                                Text("Delete All DB")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .alert(isPresented: $showDeleteConfirmation) {
                            Alert(
                                title: Text("Delete All Accounts?"),
                                message: Text("Are you sure you want to delete all accounts and reset the database? This cannot be undone."),
                                primaryButton: .destructive(Text("Delete All")) {
                                    store.deleteAllAccounts()
                                    statusMessage = "Database reset!"
                                    isSuccess = false
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }

                    if let message = statusMessage {
                        Text(message)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isSuccess ? .green : .red)
                    }
                }
                .padding(12)
            }
            .frame(width: 320)

            Divider()

            // Footer Buttons
            HStack {
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "power")
                        Text("Quit App")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Done", action: onClose)
                    .font(.system(size: 11))
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 320, height: 380)
    }
}
