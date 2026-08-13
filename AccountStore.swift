import Foundation
import Combine
import CryptoKit

struct VaultEnvelope: Codable {
    let version: Int
    let combinedData: String // Base64-encoded AES.GCM.SealedBox.combined
}

enum VaultError: Error, LocalizedError {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case corruptedVault
    case missingKey
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "Failed to generate or persist vault key."
        case .encryptionFailed: return "AES-256-GCM encryption failed."
        case .decryptionFailed: return "Vault decryption or authentication tag validation failed."
        case .corruptedVault: return "Vault file structure is malformed."
        case .missingKey: return "Vault encryption key is missing."
        case .writeFailed: return "Failed to write vault data securely to disk."
        }
    }
}

class AccountStore: ObservableObject {
    @Published var accounts: [TOTPEntry] = []
    @Published var searchText: String = ""
    @Published var lastCopiedID: UUID? = nil

    private var secretsCache: [UUID: String] = [:]
    private let storageURL: URL
    private let secretsURL: URL
    private let keyURL: URL

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
        self.keyURL = menu2FADir.appendingPathComponent("vault.key")

        loadAccounts()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSortOrderChanged),
            name: Notification.Name("SortOrderSettingChanged"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleSortOrderChanged() {
        objectWillChange.send()
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

    // MARK: - Key Management
    private func getOrCreateMasterKey() throws -> SymmetricKey {
        let fm = FileManager.default
        if fm.fileExists(atPath: keyURL.path) {
            let keyData = try Data(contentsOf: keyURL)
            guard keyData.count == 32 else {
                throw VaultError.keyGenerationFailed
            }
            return SymmetricKey(data: keyData)
        } else {
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            try writeSecurely(keyData, to: keyURL)
            return key
        }
    }

    // MARK: - Secure Write Helper (POSIX 0600)
    private func writeSecurely(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    // MARK: - Load & Migration Logic
    func loadAccounts() {
        let fm = FileManager.default

        // 1. Load account metadata
        if fm.fileExists(atPath: storageURL.path) {
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storageURL.path)
        }

        if let data = try? Data(contentsOf: storageURL),
           let decoded = try? JSONDecoder().decode([TOTPEntry].self, from: data) {
            self.accounts = decoded
        } else {
            let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let legacyURL = appSupport.appendingPathComponent("Mac2FA", isDirectory: true).appendingPathComponent("accounts.json")
            if let legacyData = try? Data(contentsOf: legacyURL),
               let legacyDecoded = try? JSONDecoder().decode([TOTPEntry].self, from: legacyData) {
                self.accounts = legacyDecoded
            } else {
                self.accounts = []
            }
        }

        // Enforce 0600 on key file if present
        if fm.fileExists(atPath: keyURL.path) {
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        }

        // 2. Load secrets vault
        guard fm.fileExists(atPath: secretsURL.path) else {
            self.secretsCache = [:]
            return
        }

        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: secretsURL.path)

        guard let rawVaultData = try? Data(contentsOf: secretsURL), !rawVaultData.isEmpty else {
            self.secretsCache = [:]
            return
        }

        // Try decrypting as encrypted VaultEnvelope
        if let envelope = try? JSONDecoder().decode(VaultEnvelope.self, from: rawVaultData),
           let combinedData = Data(base64Encoded: envelope.combinedData) {
            do {
                let key = try getOrCreateMasterKey()
                let sealedBox = try AES.GCM.SealedBox(combined: combinedData)
                let decryptedData = try AES.GCM.open(sealedBox, using: key)
                let decodedDict = try JSONDecoder().decode([String: String].self, from: decryptedData)
                
                var cache: [UUID: String] = [:]
                for (idStr, secret) in decodedDict {
                    if let uuid = UUID(uuidString: idStr) {
                        cache[uuid] = secret
                    }
                }
                self.secretsCache = cache
                return
            } catch {
                print("⚠️ Vault decryption failed: \(error.localizedDescription)")
            }
        }

        // Try parsing legacy unencrypted [String: String]
        if let legacyDict = try? JSONDecoder().decode([String: String].self, from: rawVaultData) {
            var cache: [UUID: String] = [:]
            for (idStr, secret) in legacyDict {
                if let uuid = UUID(uuidString: idStr) {
                    cache[uuid] = secret
                }
            }
            self.secretsCache = cache
            // Automatically encrypt legacy vault on load
            saveSecrets()
            print("🔒 Successfully migrated legacy unencrypted vault to AES-256-GCM.")
            return
        }

        // Corrupted vault backup strategy
        print("❌ Vault corrupted or unreadable. Backing up corrupted file...")
        let timestamp = Int(Date().timeIntervalSince1970)
        let corruptedPath = secretsURL.path + ".corrupted.\(timestamp)"
        let corruptedURL = URL(fileURLWithPath: corruptedPath)
        try? fm.moveItem(at: secretsURL, to: corruptedURL)
        self.secretsCache = [:]
    }

    // MARK: - Save Logic
    func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            try? writeSecurely(data, to: storageURL)
        }
        saveSecrets()
    }

    private func saveSecrets() {
        var encodableDict: [String: String] = [:]
        for (uuid, secret) in secretsCache {
            encodableDict[uuid.uuidString] = secret
        }

        guard let jsonData = try? JSONEncoder().encode(encodableDict) else { return }

        do {
            let key = try getOrCreateMasterKey()
            let sealedBox = try AES.GCM.seal(jsonData, using: key)
            guard let combinedData = sealedBox.combined else { return }
            
            let envelope = VaultEnvelope(version: 1, combinedData: combinedData.base64EncodedString())
            let envelopeData = try JSONEncoder().encode(envelope)
            try writeSecurely(envelopeData, to: secretsURL)
        } catch {
            print("❌ Failed to save encrypted secrets: \(error.localizedDescription)")
        }
    }

    var lastUsedIssuer: String? {
        return accounts.last(where: { !$0.issuer.trimmingCharacters(in: .whitespaces).isEmpty && $0.issuer != "General" })?.issuer
            ?? accounts.last(where: { !$0.issuer.trimmingCharacters(in: .whitespaces).isEmpty })?.issuer
    }

    func addAccount(
        name: String,
        issuer: String,
        secret: String,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: TimeInterval = 30.0
    ) -> Bool {
        let cleanSecretKey = SmartParser.cleanSecret(secret)
        guard SmartParser.isBase32Secret(cleanSecretKey) else { return false }

        let trimmedIssuer = issuer.trimmingCharacters(in: .whitespaces)
        let effectiveIssuer: String
        if trimmedIssuer.isEmpty || trimmedIssuer == "General" {
            effectiveIssuer = lastUsedIssuer ?? (trimmedIssuer.isEmpty ? "General" : trimmedIssuer)
        } else {
            effectiveIssuer = trimmedIssuer
        }

        // Deduplicate Case 1: Match by Secret (Update name, issuer, and TOTP params)
        if let existing = accounts.first(where: { secretsCache[$0.id] == cleanSecretKey }) {
            updateAccount(existing, newName: name, newIssuer: effectiveIssuer, newAlgorithm: algorithm, newDigits: digits, newPeriod: period)
            return true
        }

        // Deduplicate Case 2: Match by Issuer + Account Name (Update secret and TOTP params)
        if let existing = accounts.first(where: { $0.name.lowercased() == name.lowercased() && $0.issuer.lowercased() == effectiveIssuer.lowercased() }) {
            secretsCache[existing.id] = cleanSecretKey
            updateAccount(existing, newName: name, newIssuer: effectiveIssuer, newAlgorithm: algorithm, newDigits: digits, newPeriod: period)
            return true
        }

        // Case 3: Create New Entry
        let newEntry = TOTPEntry(name: name, issuer: effectiveIssuer, algorithm: algorithm, digits: digits, period: period)
        secretsCache[newEntry.id] = cleanSecretKey
        accounts.append(newEntry)
        saveAccounts()
        return true
    }

    func updateAccount(
        _ entry: TOTPEntry,
        newName: String,
        newIssuer: String,
        newAlgorithm: OTPAlgorithm = .sha1,
        newDigits: Int = 6,
        newPeriod: TimeInterval = 30.0
    ) {
        guard let index = accounts.firstIndex(where: { $0.id == entry.id }) else { return }
        accounts[index].name = newName
        accounts[index].issuer = newIssuer
        accounts[index].algorithm = newAlgorithm
        accounts[index].digits = newDigits
        accounts[index].period = newPeriod
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
        try? FileManager.default.removeItem(at: keyURL)
        saveAccounts()
    }

    func getSecret(for entry: TOTPEntry) -> String? {
        return secretsCache[entry.id]
    }

    func generateOTP(for entry: TOTPEntry) -> String {
        guard let secret = getSecret(for: entry),
              let otp = TOTPGenerator.generateTOTP(
                  secret: secret,
                  algorithm: entry.algorithm,
                  digits: entry.digits,
                  period: entry.period
              ) else {
            return "------"
        }
        return otp
    }

    func exportVault() -> String? {
        var exportList: [ExportableEntry] = []
        for account in accounts {
            if let secret = getSecret(for: account) {
                exportList.append(ExportableEntry(
                    name: account.name,
                    issuer: account.issuer,
                    secret: secret,
                    algorithm: account.algorithm,
                    digits: account.digits,
                    period: account.period
                ))
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
            let alg = entry.algorithm ?? .sha1
            let dig = entry.digits ?? 6
            let per = entry.period ?? 30.0
            if addAccount(name: entry.name, issuer: entry.issuer, secret: entry.secret, algorithm: alg, digits: dig, period: per) {
                importedCount += 1
            }
        }
        return importedCount
    }
}

