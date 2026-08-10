import SwiftUI
import AppKit

enum MenuLayout {
    static let contentWidth: CGFloat = 310
    static let accountRowHeight: CGFloat = 44
    static let visibleAccountCount = 10
    static let accountListHeight = accountRowHeight * CGFloat(visibleAccountCount)
}

struct SleekScrollView<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.controlSize = .mini

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = hostingView

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor)
        ])

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let hostingView = nsView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }
    }
}

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                SleekScrollView {
                    VStack(spacing: 0) {
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
            }
        }
        .frame(width: MenuLayout.contentWidth, height: MenuLayout.accountListHeight)
    }
}
