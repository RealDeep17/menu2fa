import AppKit
import SwiftUI

class KeyEquivalentHostingView<Content: View>: NSHostingView<Content> {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            if chars == "c" {
                if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) { return true }
            } else if chars == "v" {
                if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) { return true }
            } else if chars == "x" {
                if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) { return true }
            } else if chars == "a" {
                if NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self) { return true }
            } else if chars == "z" {
                if event.modifierFlags.contains(.shift) {
                    if NSApp.sendAction(Selector(("redo:")), to: nil, from: self) { return true }
                } else {
                    if NSApp.sendAction(Selector(("undo:")), to: nil, from: self) { return true }
                }
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

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
        setupMainMenu()

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

        // Listen for Preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusItemStyle),
            name: Notification.Name("StatusItemStyleChanged"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildMenu),
            name: Notification.Name("SortOrderSettingChanged"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildMenu),
            name: Notification.Name("MaxAccountsSettingChanged"),
            object: nil
        )

        // Setup Maccy-style NSMenu attached natively to status item
        menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu

        rebuildMenu()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Menu2FA", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Menu2FA", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")

        let undoItem = NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        undoItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(undoItem)

        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)

        editMenu.addItem(NSMenuItem.separator())

        let cutItem = NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        cutItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(cutItem)

        let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(copyItem)

        let pasteItem = NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        pasteItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(pasteItem)

        let selectAllItem = NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        selectAllItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(selectAllItem)

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func updateStatusItemStyle() {
        guard let button = statusItem?.button else { return }
        let showText = UserDefaults.standard.bool(forKey: "showTextInMenuBar")
        button.title = showText ? " 2FA" : ""
    }

    func menuWillOpen(_ menu: NSMenu) {
        let persist = UserDefaults.standard.bool(forKey: "persistSearchText")
        if !persist {
            accountStore.searchText = ""
        }
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        let persist = UserDefaults.standard.bool(forKey: "persistSearchText")
        if !persist {
            accountStore.searchText = ""
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu()
    }

    @objc func rebuildMenu() {
        menu.removeAllItems()

        // 1. Search & Auto-Detect Header Item
        let headerView = KeyEquivalentHostingView(rootView: MenuHeaderView(
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
        let listView = KeyEquivalentHostingView(rootView: AccountListView(
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
        let listHeight: CGFloat = count == 0 ? 80 : min(CGFloat(count) * 44.0, 680.0)
        listView.frame = NSRect(x: 0, y: 0, width: 310, height: listHeight)

        let listItem = NSMenuItem()
        listItem.view = listView
        menu.addItem(listItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Bottom Controls (Manual Add, Preferences, Quit)
        let manualAddItem = NSMenuItem(title: "➕ Manual Add Account...", action: #selector(openAddWindow), keyEquivalent: "a")
        manualAddItem.keyEquivalentModifierMask = [.command]
        manualAddItem.target = self
        menu.addItem(manualAddItem)

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
            self.addWindow = window
        }

        // The window is retained after closing, so recreate the hosting view on
        // every open. This resets AddAccountWindowView's @State instead of
        // showing the values from the previous account.
        addWindow?.contentView = NSHostingView(rootView: AddAccountWindowView(
            store: accountStore,
            onClose: { [weak self] in
                self?.addWindow?.close()
            }
        ))
        addWindow?.center()
        addWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 340, height: 480),
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
