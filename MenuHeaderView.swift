import SwiftUI
import AppKit

struct MenuHeaderView: View {
    @ObservedObject var store: AccountStore
    var isDetached: Bool = false
    var isAlwaysOnTop: Bool = false
    let onQuickAddAutoDetect: () -> Void
    let onSearchFieldCreated: (HelperNSTextField) -> Void
    let onUndock: () -> Void
    let onDockBack: () -> Void
    let onToggleAlwaysOnTop: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Search Input Field (Stretches across available width)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                
                EditableTextField(
                    text: $store.searchText,
                    placeholder: "type to search...",
                    isPlain: true,
                    focusOnAppear: true,
                    onViewCreated: onSearchFieldCreated
                )
                    .frame(height: 18)
                
                if !store.searchText.isEmpty {
                    Button(action: { store.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(6)

            // Auto-Detect Quick Add Button
            Button(action: onQuickAddAutoDetect) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Auto-detect & add from Clipboard")

            if !isDetached {
                // Undock Button
                Button(action: onUndock) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Undock into Floating Window")
            } else {
                // Always On Top Pin Button
                Button(action: onToggleAlwaysOnTop) {
                    Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isAlwaysOnTop ? .accentColor : .secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(isAlwaysOnTop ? "Always on Top (Click to unpin)" : "Pin Always on Top")

                // Dock Back Button
                Button(action: onDockBack) {
                    Image(systemName: "arrow.down.forward.square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Dock back to Menu Bar")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 42)
    }
}
