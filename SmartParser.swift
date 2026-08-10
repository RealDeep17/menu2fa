import Foundation

struct Parsed2FA {
    let name: String
    let issuer: String
    let secret: String
}

struct SmartParser {
    /// Validates if a string looks like a Base32 secret key
    static func isBase32Secret(_ string: String) -> Bool {
        let clean = string.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")
        
        guard clean.count >= 8 else { return false }
        let base32Set = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        return clean.unicodeScalars.allSatisfy { base32Set.contains($0) }
    }

    /// Cleans secret key by stripping spaces and hyphens
    static func cleanSecret(_ string: String) -> String {
        return string.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Parses multi-line input text into array of Parsed2FA items
    static func parseMultiple(_ input: String) -> [Parsed2FA] {
        let lines = input.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var results: [Parsed2FA] = []
        for line in lines {
            if let parsed = parse(line) {
                results.append(parsed)
            }
        }
        return results
    }

    /// Smartly parses raw text input into a single Parsed2FA
    static func parse(_ input: String) -> Parsed2FA? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. Try parsing as otpauth:// URI
        if trimmed.lowercased().hasPrefix("otpauth://") {
            return parseOTPAuthURI(trimmed)
        }

        // 2. Try split by tabs or spaces
        // Support formats like:
        // - "4DM2M47UQISBDUHV\tvasilolein54@gmail.com"
        // - "vasilolein54@gmail.com 4DM2M47UQISBDUHV"
        // - "GitHub: user@example.com 4DM2M47UQISBDUHV"
        let components = trimmed.components(separatedBy: CharacterSet(charactersIn: " \t\n,"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !components.isEmpty else { return nil }

        // Search for component that is a valid Base32 secret
        if let secretIndex = components.firstIndex(where: { isBase32Secret($0) }) {
            let rawSecret = components[secretIndex]
            let cleanSecretKey = cleanSecret(rawSecret)

            var remainingComponents = components
            remainingComponents.remove(at: secretIndex)

            let fullLabel = remainingComponents.joined(separator: " ")
            let (issuer, name) = parseLabel(fullLabel.isEmpty ? "Account" : fullLabel)

            return Parsed2FA(name: name, issuer: issuer, secret: cleanSecretKey)
        }

        return nil
    }

    private static func parseOTPAuthURI(_ uriString: String) -> Parsed2FA? {
        guard let url = URL(string: uriString),
              url.scheme == "otpauth",
              url.host == "totp" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems,
              let secretItem = queryItems.first(where: { $0.name.lowercased() == "secret" }),
              let secretValue = secretItem.value, !secretValue.isEmpty else { return nil }

        let cleanSecretKey = cleanSecret(secretValue)

        var label = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let decodedLabel = label.removingPercentEncoding {
            label = decodedLabel
        }

        let explicitIssuer = queryItems.first(where: { $0.name.lowercased() == "issuer" })?.value ?? ""
        let (parsedIssuer, parsedName) = parseLabel(label)

        let finalIssuer = explicitIssuer.isEmpty ? parsedIssuer : explicitIssuer
        return Parsed2FA(name: parsedName, issuer: finalIssuer, secret: cleanSecretKey)
    }

    private static func parseLabel(_ label: String) -> (issuer: String, name: String) {
        if label.contains(":") {
            let parts = label.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            return (parts[0], parts.count > 1 ? parts[1] : parts[0])
        }
        return ("General", label)
    }
}
