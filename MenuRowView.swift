import SwiftUI
import Combine

struct MenuRowView: View {
    let entry: TOTPEntry
    @ObservedObject var store: AccountStore
    let onDelete: () -> Void

    @State private var otpCode: String = ""
    @State private var timeRemaining: Int = TOTPGenerator.timeRemaining()
    @State private var isHovering = false

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var formattedOTP: String {
        guard otpCode.count == 6 else { return otpCode }
        let index = otpCode.index(otpCode.startIndex, offsetBy: 3)
        return "\(otpCode[..<index]) \(otpCode[index...])"
    }

    var body: some View {
        HStack(spacing: 10) {
            // Letter Badge
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text(String(entry.name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
            }

            // Name & Issuer
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(entry.issuer)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 6-digit OTP Code (Updates live!)
            Text(formattedOTP)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)

            // Countdown Pill (Updates live!)
            Text("\(timeRemaining)s")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(timeRemaining <= 5 ? .red : .secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(4)

            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .onAppear {
            updateCode()
        }
        .onReceive(timer) { _ in
            updateCode()
        }
    }

    private func updateCode() {
        let newOTP = store.generateOTP(for: entry)
        let newRemaining = TOTPGenerator.timeRemaining()
        if otpCode != newOTP {
            otpCode = newOTP
        }
        if timeRemaining != newRemaining {
            timeRemaining = newRemaining
        }
    }
}
