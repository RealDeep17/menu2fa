import Foundation
import Combine

class AccountStore: ObservableObject {
    @Published var accounts: [TOTPEntry] = []
    @Published var searchText: String = ""
    @Published var lastCopiedID: UUID? = nil

    private var secretsCache: [UUID: String] = [:]
    private let storageURL: URL
    private let secretsURL: URL

    init(directory: URL? = nil) {
        let menu2FADir: URL
        if let customDir = directory {
            menu2FADir = customDir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            menu2FADir = appSupport.appendingPathComponent("Menu2FA", isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: menu2FADir, withIntermediateDirectories: true)
        self.storageURL = menu2FADir.appendingPathComponent("accounts.json")
        self.secretsURL = menu2FADir.appendingPathComponent("vault.json")

        loadAccounts()
    }

    var filteredAccounts: [TOTPEntry] {
        let base: [TOTPEntry]
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            base = accounts
        } else {
            let query = searchText.lowercased()
            base = accounts.filter {
                $0.name.lowercased().contains(query) || $0.issuer.lowercased().contains(query)
            }
        }

        let sortNewestFirst = UserDefaults.standard.object(forKey: "sortNewestFirst") != nil ? UserDefaults.standard.bool(forKey: "sortNewestFirst") : true
        return sortNewestFirst ? Array(base.reversed()) : base
    }

    func loadAccounts() {
        // Load account metadata
        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([TOTPEntry].self, from: data) {
            self.accounts = decoded
        } else {
            // Check legacy Mac2FA fallback
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let legacyURL = appSupport.appendingPathComponent("Mac2FA", isDirectory: true).appendingPathComponent("accounts.json")
            if let legacyData = try? Data(contentsOf: legacyURL),
               let legacyDecoded = try? JSONDecoder().decode([TOTPEntry].self, from: legacyData) {
                self.accounts = legacyDecoded
            } else {
                self.accounts = []
            }
        }

        // Load secrets directly from local vault.json (Zero Keychain Security prompts!)
        if let secretsData = try? Data(contentsOf: secretsURL),
           let decodedSecrets = try? JSONDecoder().decode([String: String].self, from: secretsData) {
            var cache: [UUID: String] = [:]
            for (idStr, secret) in decodedSecrets {
                if let uuid = UUID(uuidString: idStr) {
                    cache[uuid] = secret
                }
            }
            self.secretsCache = cache
        } else {
            self.secretsCache = [:]
        }
    }

    func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            try? data.write(to: storageURL, options: .atomic)
        }
        saveSecrets()
    }

    private func saveSecrets() {
        var encodableDict: [String: String] = [:]
        for (uuid, secret) in secretsCache {
            encodableDict[uuid.uuidString] = secret
        }
        if let data = try? JSONEncoder().encode(encodableDict) {
            try? data.write(to: secretsURL, options: .atomic)
        }
    }

    var lastUsedIssuer: String? {
        return accounts.last(where: { !$0.issuer.trimmingCharacters(in: .whitespaces).isEmpty && $0.issuer != "General" })?.issuer
            ?? accounts.last(where: { !$0.issuer.trimmingCharacters(in: .whitespaces).isEmpty })?.issuer
    }

    func addAccount(name: String, issuer: String, secret: String) -> Bool {
        let cleanSecretKey = SmartParser.cleanSecret(secret)
        guard SmartParser.isBase32Secret(cleanSecretKey) else { return false }

        let trimmedIssuer = issuer.trimmingCharacters(in: .whitespaces)
        let effectiveIssuer: String
        if trimmedIssuer.isEmpty || trimmedIssuer == "General" {
            effectiveIssuer = lastUsedIssuer ?? (trimmedIssuer.isEmpty ? "General" : trimmedIssuer)
        } else {
            effectiveIssuer = trimmedIssuer
        }

        // Check for duplicate accounts with identical secret
        if let existing = accounts.first(where: { secretsCache[$0.id] == cleanSecretKey }) {
            // Update name and issuer of existing entry
            updateAccount(existing, newName: name, newIssuer: effectiveIssuer)
            return true
        }

        // Check for duplicate account with identical name & issuer
        if let existing = accounts.first(where: { $0.name.lowercased() == name.lowercased() && $0.issuer.lowercased() == effectiveIssuer.lowercased() }) {
            secretsCache[existing.id] = cleanSecretKey
            saveAccounts()
            return true
        }

        let newEntry = TOTPEntry(name: name, issuer: effectiveIssuer)
        secretsCache[newEntry.id] = cleanSecretKey
        accounts.append(newEntry)
        saveAccounts()
        return true
    }

    func updateAccount(_ entry: TOTPEntry, newName: String, newIssuer: String) {
        guard let index = accounts.firstIndex(where: { $0.id == entry.id }) else { return }
        accounts[index].name = newName
        accounts[index].issuer = newIssuer
        saveAccounts()
    }

    func deleteAccount(_ entry: TOTPEntry) {
        secretsCache.removeValue(forKey: entry.id)
        accounts.removeAll { $0.id == entry.id }
        saveAccounts()
    }

    func deleteAllAccounts() {
        accounts.removeAll()
        secretsCache.removeAll()
        try? FileManager.default.removeItem(at: storageURL)
        try? FileManager.default.removeItem(at: secretsURL)
        saveAccounts()
    }

    func getSecret(for entry: TOTPEntry) -> String? {
        return secretsCache[entry.id]
    }

    func generateOTP(for entry: TOTPEntry) -> String {
        guard let secret = getSecret(for: entry),
              let otp = TOTPGenerator.generateOTP(secret: secret) else {
            return "------"
        }
        return otp
    }

    func exportVault() -> String? {
        var exportList: [ExportableEntry] = []
        for account in accounts {
            if let secret = getSecret(for: account) {
                exportList.append(ExportableEntry(name: account.name, issuer: account.issuer, secret: secret))
            }
        }
        guard let data = try? JSONEncoder().encode(exportList) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func importVault(jsonString: String) -> Int {
        guard let data = jsonString.data(using: .utf8),
              let entries = try? JSONDecoder().decode([ExportableEntry].self, from: data) else {
            return 0
        }

        var importedCount = 0
        for entry in entries {
            if addAccount(name: entry.name, issuer: entry.issuer, secret: entry.secret) {
                importedCount += 1
            }
        }
        return importedCount
    }
}
