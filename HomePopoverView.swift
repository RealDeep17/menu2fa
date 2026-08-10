import SwiftUI

struct HomePopoverView: View {
    @ObservedObject var store: AccountStore
    var isDetached: Bool = false
    var isAlwaysOnTop: Bool = false
    let onSearchFieldCreated: (HelperNSTextField) -> Void
    let onQuickAddAutoDetect: () -> Void
    let onManualAdd: () -> Void
    let onPreferences: () -> Void
    let onQuit: () -> Void
    let onDelete: (TOTPEntry) -> Void
    let onCopy: () -> Void
    let onUndock: () -> Void
    let onDockBack: () -> Void
    let onToggleAlwaysOnTop: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MenuHeaderView(
                store: store,
                isDetached: isDetached,
                isAlwaysOnTop: isAlwaysOnTop,
                onQuickAddAutoDetect: onQuickAddAutoDetect,
                onSearchFieldCreated: onSearchFieldCreated,
                onUndock: onUndock,
                onDockBack: onDockBack,
                onToggleAlwaysOnTop: onToggleAlwaysOnTop
            )

            Divider()

            AccountListView(
                store: store,
                onDelete: onDelete,
                onCopy: onCopy
            )

            Divider()

            menuAction("➕ Manual Add Account...", action: onManualAdd)
            menuAction("⚙️ Preferences...", action: onPreferences)

            Divider()

            menuAction("Quit Menu2FA", action: onQuit)
        }
        .frame(width: MenuLayout.contentWidth)
    }

    private func menuAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}
