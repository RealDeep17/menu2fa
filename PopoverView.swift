import SwiftUI
import AppKit

struct PopoverView: View {
    @ObservedObject var store: AccountStore
    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false
    @State private var toastMessage: String? = nil
    @State private var timeRemaining: Int = TOTPGenerator.timeRemaining()
    @State private var progressRatio: Double = TOTPGenerator.timeProgress()

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    
                EditableTextField(text: $store.searchText, placeholder: "Search accounts...", isPlain: true)
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

                // Add Button
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Add new 2FA account")

                // Settings Button
                Button(action: { showingSettingsSheet = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings & Launch at Login")

                // Power / Quit App Button
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Quit Menu2FA")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // 30-Second Countdown Progress Bar (Only visible when accounts exist)
            if !store.accounts.isEmpty {
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 3)
                            Capsule()
                                .fill(timeRemaining <= 5 ? Color.red : Color.accentColor)
                                .frame(width: max(0, geo.size.width * CGFloat(progressRatio)), height: 3)
                                .animation(.linear(duration: 0.5), value: progressRatio)
                        }
                    }
                    .frame(height: 3)

                    Text("\(timeRemaining)s")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(timeRemaining <= 5 ? .red : .secondary)
                        .frame(width: 24, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider()
            }

            // Account List or Empty State
            if store.filteredAccounts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "key.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    if store.searchText.isEmpty {
                        Text("No 2FA Accounts Yet")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Click '+' and paste 'name secret' or 'secret name'")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    } else {
                        Text("No matching accounts")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .frame(height: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.filteredAccounts) { entry in
                            AccountRowView(
                                entry: entry,
                                store: store,
                                isCopied: store.lastCopiedID == entry.id,
                                onCopy: {
                                    store.lastCopiedID = entry.id
                                    showToast("Copied to clipboard!")
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        if store.lastCopiedID == entry.id {
                                            store.lastCopiedID = nil
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: 360)
            }

            // Bottom Toast Bar
            if let toast = toastMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.15))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 300)
        .sheet(isPresented: $showingAddSheet) {
            AddAccountView(store: store, isPresented: $showingAddSheet)
        }
        .sheet(isPresented: $showingSettingsSheet) {
            SettingsView(store: store, isPresented: $showingSettingsSheet)
        }
        .onReceive(timer) { _ in
            // Only calculate progress if accounts exist
            if !store.accounts.isEmpty {
                timeRemaining = TOTPGenerator.timeRemaining()
                progressRatio = TOTPGenerator.timeProgress()
            }
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            toastMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                if toastMessage == text {
                    toastMessage = nil
                }
            }
        }
    }
}
