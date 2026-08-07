import Foundation
import Combine

class AccountStore: ObservableObject {
    @Published var accounts: [TOTPEntry] = []
    @Published var searchText: String = ""
    @Published var lastCopiedID: UUID? = nil

    private var secretsCache: [UUID: String] = [:]
    private let storageURL: URL
    private let secretsURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let menu2FADir = appSupport.appendingPathComponent("Menu2FA", isDirectory: true)

        try? FileManager.default.createDirectory(at: menu2FADir, withIntermediateDirectories: true)
        self.storageURL = menu2FADir.appendingPathComponent("accounts.json")
        self.secretsURL = menu2FADir.appendingPathComponent("vault.json")

        loadAccounts()
    }

    var filteredAccounts: [TOTPEntry] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return accounts
        }
        let query = searchText.lowercased()
        return accounts.filter {
            $0.name.lowercased().contains(query) || $0.issuer.lowercased().contains(query)
        }
    }

    func loadAccounts() {
        // Load account metadata
        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([TOTPEntry].self, from: data) {
            self.accounts = decoded
        } else {
            self.accounts = []
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

    func addAccount(name: String, issuer: String, secret: String) -> Bool {
        let cleanSecretKey = SmartParser.cleanSecret(secret)
        guard SmartParser.isBase32Secret(cleanSecretKey) else { return false }

        let newEntry = TOTPEntry(name: name, issuer: issuer)
        
        // Store secret directly in local vault (No macOS Keychain prompts!)
        secretsCache[newEntry.id] = cleanSecretKey

        accounts.append(newEntry)
        saveAccounts()
        return true
    }

    func deleteAccount(_ entry: TOTPEntry) {
        secretsCache.removeValue(forKey: entry.id)
        accounts.removeAll { $0.id == entry.id }
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
