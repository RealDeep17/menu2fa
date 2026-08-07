import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let accountStore = AccountStore()

    private var addWindow: NSWindow?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enforce single-instance application (Prevent duplicate menu bar icons)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.menu2fa.app")
        if runningApps.contains(where: { $0.processIdentifier != currentPID }) {
            print("Menu2FA is already running. Terminating duplicate instance.")
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)

        // Create NSStatusItem using native SF Symbol lock.shield.fill
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold, scale: .medium)
                let image = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "Menu2FA")?.withSymbolConfiguration(config)
                image?.isTemplate = true
                button.image = image
            } else {
                button.title = "🔑"
            }
        }
        updateStatusItemStyle()

        // Listen for Menu Bar Style changes from Preferences
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusItemStyle),
            name: Notification.Name("StatusItemStyleChanged"),
            object: nil
        )

        // Setup Maccy-style NSMenu attached natively to status item
        menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        rebuildMenu()
    }

    @objc private func updateStatusItemStyle() {
        guard let button = statusItem?.button else { return }
        let showText = UserDefaults.standard.bool(forKey: "showTextInMenuBar")
        button.title = showText ? " 2FA" : ""
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc func rebuildMenu() {
        menu.removeAllItems()

        // 1. Search & Auto-Detect Header Item
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

        // 2. Scrollable Account List (Smooth ScrollView capped at 300px height)
        let listView = NSHostingView(rootView: AccountListView(
            store: accountStore,
            onDelete: { [weak self] entry in
                self?.accountStore.deleteAccount(entry)
                self?.rebuildMenu()
            },
            onCopy: { [weak self] in
                self?.menu.cancelTracking()
            }
        ))
        
        let count = accountStore.filteredAccounts.count
        let listHeight: CGFloat = count == 0 ? 80 : min(CGFloat(count) * 44.0, 300.0)
        listView.frame = NSRect(x: 0, y: 0, width: 310, height: listHeight)

        let listItem = NSMenuItem()
        listItem.view = listView
        menu.addItem(listItem)

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
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 380),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Menu2FA Preferences"
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
