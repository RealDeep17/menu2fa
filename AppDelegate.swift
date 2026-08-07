import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let accountStore = AccountStore()

    private var addWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Create NSStatusItem
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
                let image = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "Menu2FA")?.withSymbolConfiguration(config)
                image?.isTemplate = true
                button.image = image
            }
            button.title = " 2FA"
        }

        // Setup Maccy-style NSMenu attached natively to status item
        menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        rebuildMenu()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    func rebuildMenu() {
        menu.removeAllItems()

        // 1. Search & Auto-Detect Header Item (Fills menu width)
        let headerView = NSHostingView(rootView: MenuHeaderView(
            store: accountStore,
            onQuickAddAutoDetect: { [weak self] in
                self?.handleQuickAddAutoDetect()
            }
        ))
        headerView.frame = NSRect(x: 0, y: 0, width: 310, height: 42)
        let headerItem = NSMenuItem()
        headerItem.view = headerView
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        // 2. Account List Items
        let filtered = accountStore.filteredAccounts
        if filtered.isEmpty {
            let emptyItem = NSMenuItem(title: accountStore.searchText.isEmpty ? "  No 2FA Accounts Yet" : "  No matching accounts", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, entry) in filtered.enumerated() {
                let rowView = NSHostingView(rootView: MenuRowView(
                    entry: entry,
                    store: accountStore,
                    onDelete: { [weak self] in
                        self?.accountStore.deleteAccount(entry)
                        self?.rebuildMenu()
                    }
                ))
                rowView.frame = NSRect(x: 0, y: 0, width: 310, height: 44)

                let menuItem = NSMenuItem()
                menuItem.view = rowView
                menuItem.target = self
                menuItem.action = #selector(accountSelected(_:))
                menuItem.representedObject = entry
                
                if index < 9 {
                    menuItem.keyEquivalent = "\(index + 1)"
                    menuItem.keyEquivalentModifierMask = [.command]
                }

                menu.addItem(menuItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // 3. Bottom Controls (Manual Add, QR Code Scan, Preferences, Quit)
        let manualAddItem = NSMenuItem(title: "➕ Manual Add Account...", action: #selector(openAddWindow), keyEquivalent: "a")
        manualAddItem.keyEquivalentModifierMask = [.command]
        manualAddItem.target = self
        menu.addItem(manualAddItem)

        let qrScanItem = NSMenuItem(title: "📷 Scan QR Code (Screen / Clipboard)...", action: #selector(scanQRCodeOnScreen), keyEquivalent: "s")
        qrScanItem.keyEquivalentModifierMask = [.command]
        qrScanItem.target = self
        menu.addItem(qrScanItem)

        let preferencesItem = NSMenuItem(title: "⚙️ Preferences...", action: #selector(openSettingsWindow), keyEquivalent: ",")
        preferencesItem.keyEquivalentModifierMask = [.command]
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Menu2FA", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func handleQuickAddAutoDetect() {
        // Do NOT cancel tracking so the menu stays open when adding from clipboard!
        if let clipboard = NSPasteboard.general.string(forType: .string) {
            let parsedAccounts = SmartParser.parseMultiple(clipboard)
            if !parsedAccounts.isEmpty {
                var addedCount = 0
                for account in parsedAccounts {
                    if accountStore.addAccount(name: account.name, issuer: account.issuer, secret: account.secret) {
                        addedCount += 1
                    }
                }

                if addedCount > 0 {
                    NSSound.beep()
                    rebuildMenu()
                    return
                }
            }
        }

        // Fallback to manual window if clipboard doesn't contain valid 2FA secret(s)
        menu.cancelTracking()
        openAddWindow()
    }

    @objc private func scanQRCodeOnScreen() {
        menu.cancelTracking()

        QRCodeScanner.scanScreenOrClipboard { [weak self] parsed, errorMessage in
            guard let self = self else { return }
            if let parsed = parsed {
                if self.accountStore.addAccount(name: parsed.name, issuer: parsed.issuer, secret: parsed.secret) {
                    NSSound.beep()
                    self.rebuildMenu()
                } else {
                    self.showAlert(title: "Failed to Add", message: "Failed to save secret from scanned QR code.")
                }
            } else if let errorMessage = errorMessage {
                self.showAlert(title: "QR Code Scan Result", message: errorMessage)
            }
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func accountSelected(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? TOTPEntry else { return }
        let code = accountStore.generateOTP(for: entry)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
    }

    @objc private func openAddWindow() {
        if addWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 340),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Add 2FA Account(s)"
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.contentView = NSHostingView(rootView: AddAccountWindowView(
                store: accountStore,
                onClose: { [weak self] in
                    self?.addWindow?.close()
                }
            ))
            self.addWindow = window
        }
        addWindow?.center()
        addWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 340),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Menu2FA Settings"
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.contentView = NSHostingView(rootView: SettingsWindowView(
                store: accountStore,
                onClose: { [weak self] in
                    self?.settingsWindow?.close()
                }
            ))
            self.settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

@main
struct Menu2FAApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
