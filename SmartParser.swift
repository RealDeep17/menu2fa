import Foundation

struct ParsedOTPAccount: Equatable {
    var name: String
    var issuer: String
    var secret: String
    var algorithm: OTPAlgorithm
    var digits: Int
    var period: TimeInterval

    init(
        name: String,
        issuer: String,
        secret: String,
        algorithm: OTPAlgorithm = .sha1,
        digits: Int = 6,
        period: TimeInterval = 30.0
    ) {
        self.name = name
        self.issuer = issuer
        self.secret = secret
        self.algorithm = algorithm
        self.digits = digits
        self.period = period
    }
}

typealias Parsed2FA = ParsedOTPAccount

struct SmartParser {
    /// Validates if a string looks like a Base32 secret key
    static func isBase32Secret(_ string: String) -> Bool {
        return secretScore(string) > 0
    }

    /// Calculates a confidence score for whether a string component is a TOTP secret key
    static func secretScore(_ string: String) -> Int {
        let clean = cleanSecret(string)
        guard clean.count >= 8 else { return -1000 }

        // Must consist only of valid Base32 characters
        let base32Set = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        guard clean.unicodeScalars.allSatisfy({ base32Set.contains($0) }) else {
            return -1000
        }

        let lower = string.lowercased()
        // Strong indicators that this is a label/email/URL, NOT a secret key
        if lower.contains("@") || lower.contains(".com") || lower.contains(".org") ||
           lower.contains(".net") || lower.contains(".io") || lower.contains("http") ||
           lower.contains(":") || lower.contains("/") {
            return -1000
        }

        var score = 10

        // Bonus for standard secret key lengths (16, 24, 26, 32, 40, 64)
        let standardLengths = [16, 24, 26, 32, 40, 64]
        if standardLengths.contains(clean.count) {
            score += 25
        }

        // Bonus for presence of Base32 digits (2, 3, 4, 5, 6, 7)
        let digitSet = CharacterSet(charactersIn: "234567")
        let digitCount = clean.unicodeScalars.filter { digitSet.contains($0) }.count
        if digitCount > 0 {
            score += 30
        }

        // Bonus for high character entropy/variety
        let uniqueChars = Set(clean)
        score += min(uniqueChars.count * 2, 20)

        return score
    }

    /// Cleans secret key by stripping spaces, tabs, newlines, non-breaking spaces, hyphens, en-dashes, em-dashes, figure dashes, horizontal bars, equals signs, and zero-width spaces
    static func cleanSecret(_ string: String) -> String {
        let uppercase = string.uppercased()
        let toRemove: Set<Character> = ["-", "–", "—", "‒", "―", "=", "\u{200B}", "\u{200C}", "\u{200D}", "\u{FEFF}"]
        return uppercase.filter { char in
            !char.isWhitespace && !char.isNewline && !toRemove.contains(char)
        }
    }

    /// Parses multi-line input text into array of ParsedOTPAccount items
    static func parseMultiple(_ input: String) -> [ParsedOTPAccount] {
        let lines = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var results: [ParsedOTPAccount] = []
        for line in lines {
            if let parsed = parse(line) {
                results.append(parsed)
            }
        }
        return results
    }

    /// Smartly parses raw text input into a single ParsedOTPAccount
    static func parse(_ input: String) -> ParsedOTPAccount? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. Try parsing as otpauth:// URI
        if trimmed.lowercased().hasPrefix("otpauth://") {
            return parseOTPAuthURI(trimmed)
        }

        // 2. Try split by tabs, spaces, or commas
        let components = trimmed.components(separatedBy: CharacterSet(charactersIn: " \t\n,"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !components.isEmpty else { return nil }

        // Score each component to find the best candidate secret key
        var bestIndex: Int? = nil
        var maxScore = 0

        for (idx, comp) in components.enumerated() {
            let score = secretScore(comp)
            if score > maxScore {
                maxScore = score
                bestIndex = idx
            }
        }

        guard let secretIndex = bestIndex else { return nil }

        let rawSecret = components[secretIndex]
        let cleanSecretKey = cleanSecret(rawSecret)

        var remainingComponents = components
        remainingComponents.remove(at: secretIndex)

        var name: String = ""
        var issuer: String = ""

        if remainingComponents.isEmpty {
            name = "Account"
            issuer = ""
        } else if remainingComponents.count == 1 {
            let label = remainingComponents[0]
            let (parsedIssuer, parsedName) = parseLabel(label)
            issuer = parsedIssuer
            name = parsedName
        } else if remainingComponents.count == 2 {
            let fullLabel = remainingComponents.joined(separator: " ")
            if fullLabel.contains(":") {
                let (parsedIssuer, parsedName) = parseLabel(fullLabel)
                issuer = parsedIssuer
                name = parsedName
            } else if secretIndex == 0 {
                // Format: SECRET + NAME + ISSUER
                name = remainingComponents[0]
                issuer = remainingComponents[1]
            } else if remainingComponents[1].contains("@") || remainingComponents[1].contains(".") {
                // Format: ISSUER + NAME + SECRET
                issuer = remainingComponents[0]
                name = remainingComponents[1]
            } else {
                // Default: NAME + ISSUER
                name = remainingComponents[0]
                issuer = remainingComponents[1]
            }
        } else {
            let fullLabel = remainingComponents.joined(separator: " ")
            if fullLabel.contains(":") {
                let (parsedIssuer, parsedName) = parseLabel(fullLabel)
                issuer = parsedIssuer
                name = parsedName
            } else if secretIndex == 0 {
                // Format: SECRET + NAME + ISSUER
                name = remainingComponents[0]
                issuer = remainingComponents.dropFirst().joined(separator: " ")
            } else {
                name = remainingComponents.dropLast().joined(separator: " ")
                issuer = remainingComponents.last ?? ""
            }
        }

        return ParsedOTPAccount(name: name, issuer: issuer, secret: cleanSecretKey)
    }

    private static func parseOTPAuthURI(_ uriString: String) -> ParsedOTPAccount? {
        var encodedURI = uriString
        if uriString.contains(" ") {
            encodedURI = uriString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? uriString
        }

        guard let url = URL(string: encodedURI) ?? URL(string: uriString),
              let scheme = url.scheme?.lowercased(), scheme == "otpauth",
              let host = url.host?.lowercased(), host == "totp" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems,
              let secretItem = queryItems.first(where: { $0.name.lowercased() == "secret" }),
              let secretValue = secretItem.value, !secretValue.isEmpty else { return nil }

        let cleanSecretKey = cleanSecret(secretValue)

        // Extract path label preserving encoded colons (%3A) before percent decoding
        let rawPath = components?.percentEncodedPath ?? url.path
        let trimmedPath = rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let (parsedIssuer, parsedName) = parseEncodedLabel(trimmedPath.isEmpty ? "Account" : trimmedPath)

        let explicitIssuer = queryItems.first(where: { $0.name.lowercased() == "issuer" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let finalIssuer = explicitIssuer.isEmpty ? parsedIssuer : explicitIssuer

        // Parse query parameters: algorithm, digits, period
        let algorithmVal = queryItems.first(where: { $0.name.lowercased() == "algorithm" })?.value?.lowercased()
        let algorithm: OTPAlgorithm
        switch algorithmVal {
        case "sha256": algorithm = .sha256
        case "sha512": algorithm = .sha512
        default: algorithm = .sha1
        }

        let digitsVal = queryItems.first(where: { $0.name.lowercased() == "digits" })?.value
        let digits: Int
        if let d = digitsVal.flatMap(Int.init), (d == 6 || d == 7 || d == 8) {
            digits = d
        } else {
            digits = 6
        }

        let periodVal = queryItems.first(where: { $0.name.lowercased() == "period" })?.value
        let period: TimeInterval
        if let p = periodVal.flatMap(TimeInterval.init), p > 0 {
            period = p
        } else {
            period = 30.0
        }

        return ParsedOTPAccount(
            name: parsedName,
            issuer: finalIssuer,
            secret: cleanSecretKey,
            algorithm: algorithm,
            digits: digits,
            period: period
        )
    }

    private static func parseEncodedLabel(_ label: String) -> (issuer: String, name: String) {
        if label.contains(":") {
            let parts = label.split(separator: ":", maxSplits: 1).map { String($0) }
            let issuerPart = (parts[0].removingPercentEncoding ?? parts[0]).trimmingCharacters(in: .whitespaces)
            let namePart = (parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : parts[0]).trimmingCharacters(in: .whitespaces)
            return (issuerPart, namePart)
        }
        let decoded = (label.removingPercentEncoding ?? label).trimmingCharacters(in: .whitespaces)
        return ("", decoded)
    }

    private static func parseLabel(_ label: String) -> (issuer: String, name: String) {
        if label.contains(":") {
            let parts = label.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            return (parts[0], parts.count > 1 ? parts[1] : parts[0])
        }
        return ("", label)
    }
}

