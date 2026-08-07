import SwiftUI

struct AccountListView: View {
    @ObservedObject var store: AccountStore
    let onDelete: (TOTPEntry) -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if store.filteredAccounts.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "key.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(store.searchText.isEmpty ? "No 2FA Accounts Yet" : "No matching accounts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(width: 310, height: 80)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(store.filteredAccounts) { entry in
                            MenuRowView(
                                entry: entry,
                                store: store,
                                onDelete: { onDelete(entry) },
                                onCopy: onCopy
                            )
                        }
                    }
                }
                .frame(width: 310)
                .frame(maxHeight: 300)
            }
        }
    }
}
