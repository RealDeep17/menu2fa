import SwiftUI
import AppKit

struct AccountRowView: View {
    let entry: TOTPEntry
    @ObservedObject var store: AccountStore
    let isCopied: Bool
    let onCopy: () -> Void

    @State private var currentOTP: String = "------"
    @State private var isHovering = false
    @State private var showDeleteConfirmation = false

    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var formattedOTP: String {
        guard currentOTP.count == 6 else { return currentOTP }
        let index = currentOTP.index(currentOTP.startIndex, offsetBy: 3)
        return "\(currentOTP[..<index]) \(currentOTP[index...])"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Badge / Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 34, height: 34)
                
                Text(String(entry.name.prefix(1)).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
            }

            // Name & Issuer
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(entry.issuer)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Code & Action
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedOTP)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(isCopied ? .green : .primary)

                if isCopied {
                    Text("Copied!")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
            }

            if isHovering {
                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
                .help("Delete account")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCopied ? Color.green.opacity(0.1) : (isHovering ? Color.secondary.opacity(0.12) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            let code = store.generateOTP(for: entry)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(code, forType: .string)
            onCopy()
        }
        .onAppear {
            updateOTP()
        }
        .onReceive(timer) { _ in
            updateOTP()
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                store.deleteAccount(entry)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(entry.name)? This action cannot be undone.")
        }
    }

    private func updateOTP() {
        let code = store.generateOTP(for: entry)
        if currentOTP != code {
            currentOTP = code
        }
    }
}
