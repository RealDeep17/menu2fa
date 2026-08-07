import SwiftUI
import AppKit

struct MenuHeaderView: View {
    @ObservedObject var store: AccountStore
    let onQuickAddAutoDetect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Search Input Field (Stretches across available width)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                
                TextField("type to search...", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Auto-detect & add from Clipboard")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 42)
    }
}
