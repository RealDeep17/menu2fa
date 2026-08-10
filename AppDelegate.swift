import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let accountStore = AccountStore()
    private let popover = NSPopover()
    private var detachedWindow: NSWindow?
    private weak var searchTextField: HelperNSTextField?
    private var keyboardMonitor: Any?
    private var popoverAnchor: NSPoint?
    private var addWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private var isDetached: Bool {
        get { UserDefaults.standard.bool(forKey: "isDetached") }
        set { UserDefaults.standard.set(newValue, forKey: "isDetached") }
    }

    private var isAlwaysOnTop: Bool {
        get { UserDefaults.standard.object(forKey: "isAlwaysOnTop") != nil ? UserDefaults.standard.bool(forKey: "isAlwaysOnTop") : true }
        set { UserDefaults.standard.set(newValue, forKey: "isAlwaysOnTop") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.menu2fa.app")
        if runningApps.contains(where: { $0.processIdentifier != currentPID }) {
            print("Menu2FA is already running. Terminating duplicate instance.")
            NSApp.terminate(nil)
            return
        }

        NSApp.setActivationPolicy(.accessory)
        setupMainMenu()
        setupStatusItem()
        setupPopover()
        installKeyboardMonitor()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusItemStyle),
            name: Notification.Name("StatusItemStyleChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleUndockNotification),
            name: Notification.Name("ToggleUndockMode"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAlwaysOnTopNotification),
            name: Notification.Name("AlwaysOnTopSettingChanged"),
            object: nil
        )

        if isDetached {
            DispatchQueue.main.async { [weak self] in
                self?.openDetachedWindow()
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem.button else { return }
        if #available(macOS 11.0, *) {
            let config = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold, scale: .medium)
            let image = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "Menu2FA")?.withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
        } else {
            button.title = "🔑"
        }
        button.target = self
        button.action = #selector(togglePopover(_:))
        updateStatusItemStyle()
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: makeHomePopoverView(isDetached: false))
    }

    private func makeHomePopoverView(isDetached: Bool) -> HomePopoverView {
        HomePopoverView(
            store: accountStore,
            isDetached: isDetached,
            isAlwaysOnTop: isAlwaysOnTop,
            onSearchFieldCreated: { [weak self] textField in
                self?.searchTextField = textField
            },
            onQuickAddAutoDetect: { [weak self] in
                self?.handleQuickAddAutoDetect()
            },
            onManualAdd: { [weak self] in
                if !isDetached { self?.popover.performClose(nil) }
                self?.openAddWindow()
            },
            onPreferences: { [weak self] in
                if !isDetached { self?.popover.performClose(nil) }
                self?.openSettingsWindow()
            },
            onQuit: {
                NSApplication.shared.terminate(nil)
            },
            onDelete: { [weak self] entry in
                self?.accountStore.deleteAccount(entry)
            },
            onCopy: { [weak self] in
                if !isDetached { self?.popover.performClose(nil) }
            },
            onUndock: { [weak self] in
                self?.undockWindow()
            },
            onDockBack: { [weak self] in
                self?.dockBackToMenuBar()
            },
            onToggleAlwaysOnTop: { [weak self] in
                self?.toggleAlwaysOnTop()
            }
        )
    }

    private func undockWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }
        isDetached = true
        openDetachedWindow()
    }

    private func dockBackToMenuBar() {
        isDetached = false
        detachedWindow?.close()
        detachedWindow = nil
        popover.contentViewController = NSHostingController(rootView: makeHomePopoverView(isDetached: false))

        guard let button = statusItem.button else { return }
        popoverAnchor = NSEvent.mouseLocation
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        positionPopover()
        focusSearchField()
    }

    private func toggleAlwaysOnTop() {
        isAlwaysOnTop.toggle()
        if let detachedWindow {
            detachedWindow.level = isAlwaysOnTop ? .floating : .normal
            detachedWindow.contentView = NSHostingView(rootView: makeHomePopoverView(isDetached: true))
        }
    }

    private func openDetachedWindow() {
        if detachedWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: MenuLayout.contentWidth, height: 480),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Menu2FA"
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            detachedWindow = window
        }

        detachedWindow?.level = isAlwaysOnTop ? .floating : .normal
        detachedWindow?.contentView = NSHostingView(rootView: makeHomePopoverView(isDetached: true))
        detachedWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        focusSearchField()
    }

    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == detachedWindow {
            isDetached = false
            popover.contentViewController = NSHostingController(rootView: makeHomePopoverView(isDetached: false))
        }
    }

    @objc private func handleToggleUndockNotification() {
        if isDetached {
            dockBackToMenuBar()
        } else {
            undockWindow()
        }
    }

    @objc private func handleAlwaysOnTopNotification() {
        if let detachedWindow {
            detachedWindow.level = isAlwaysOnTop ? .floating : .normal
            detachedWindow.contentView = NSHostingView(rootView: makeHomePopoverView(isDetached: true))
        }
    }

    private func installKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let isPopoverShown = self.popover.isShown
            let isDetachedShown = self.detachedWindow?.isVisible == true
            guard isPopoverShown || isDetachedShown else { return event }

            // If focus is currently in a text field / editor, let AppKit handle text editing natively
            let activeWindow = isDetachedShown ? self.detachedWindow : self.popover.contentViewController?.view.window
            if let window = activeWindow,
               let firstResponder = window.firstResponder,
               (firstResponder is NSTextView || firstResponder is NSTextField) {
                return event
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if !flags.contains(.command) && !flags.contains(.control) && !flags.contains(.option) {
                if let typedText = event.characters,
                   typedText.rangeOfCharacter(from: .controlCharacters) == nil,
                   let textField = self.searchTextField {
                    textField.window?.makeFirstResponder(textField)
                }
            }

            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About Menu2FA", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit Menu2FA", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func updateStatusItemStyle() {
        guard let button = statusItem?.button else { return }
        button.title = UserDefaults.standard.bool(forKey: "showTextInMenuBar") ? " 2FA" : ""
    }

    @objc private func togglePopover(_ sender: Any?) {
        if isDetached {
            if let detachedWindow {
                if detachedWindow.isVisible && detachedWindow.isKeyWindow {
                    detachedWindow.orderOut(sender)
                } else {
                    detachedWindow.makeKeyAndOrderFront(sender)
                    NSApp.activate(ignoringOtherApps: true)
                }
            } else {
                openDetachedWindow()
            }
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        if !UserDefaults.standard.bool(forKey: "persistSearchText") {
            accountStore.searchText = ""
        }

        guard let button = statusItem.button else { return }
        popoverAnchor = NSEvent.mouseLocation
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        positionPopover()
        focusSearchField()
    }

    func popoverDidShow(_ notification: Notification) {
        positionPopover()
        focusSearchField()
    }

    func popoverDidClose(_ notification: Notification) {
        popoverAnchor = nil
        if !UserDefaults.standard.bool(forKey: "persistSearchText") {
            accountStore.searchText = ""
        }
    }

    private func positionPopover() {
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.popover.isShown,
                  let window = self.popover.contentViewController?.view.window,
                  let anchor = self.popoverAnchor else {
                return
            }

            let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) })
                ?? window.screen
                ?? NSScreen.main
            guard let screen else { return }

            let visibleFrame = screen.visibleFrame
            let horizontalInset: CGFloat = 6
            var frame = window.frame

            if frame.width >= visibleFrame.width - horizontalInset * 2 {
                frame.origin.x = visibleFrame.minX + horizontalInset
            } else {
                frame.origin.x = min(
                    max(anchor.x - frame.width / 2, visibleFrame.minX + horizontalInset),
                    visibleFrame.maxX - frame.width - horizontalInset
                )
            }

            frame.origin.y = frame.height >= visibleFrame.height
                ? visibleFrame.minY + horizontalInset
                : visibleFrame.maxY - frame.height

            window.setFrame(frame, display: true)
        }
    }

    private func focusSearchField(retryCount: Int = 0) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let isDetachedShown = self.detachedWindow?.isVisible == true
            let isPopoverShown = self.popover.isShown
            guard isPopoverShown || isDetachedShown, let textField = self.searchTextField else { return }
            guard let window = textField.window else {
                if retryCount < 3 {
                    self.focusSearchField(retryCount: retryCount + 1)
                }
                return
            }
            if window.canBecomeKey {
                window.makeKey()
            }
            if !window.makeFirstResponder(textField), retryCount < 3 {
                self.focusSearchField(retryCount: retryCount + 1)
            }
        }
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
                    return
                }
            }
        }

        if !isDetached { popover.performClose(nil) }
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
            addWindow = window
        }

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
            settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
