import Foundation
import CryptoKit

struct TOTPGenerator {
    /// Decodes a Base32 string into Data
    static func decodeBase32(_ string: String) -> Data? {
        let cleanString = string.uppercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "=", with: "")

        guard !cleanString.isEmpty else { return nil }

        let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var buffer = 0
        var bitsLeft = 0
        var data = Data()

        for char in cleanString {
            guard let index = base32Alphabet.firstIndex(of: char) else {
                return nil // Invalid Base32 character
            }
            let val = base32Alphabet.distance(from: base32Alphabet.startIndex, to: index)
            buffer = (buffer << 5) | val
            bitsLeft += 5

            if bitsLeft >= 8 {
                bitsLeft -= 8
                let byte = UInt8((buffer >> bitsLeft) & 0xFF)
                data.append(byte)
            }
        }

        return data.isEmpty ? nil : data
    }

    /// Generates a TOTP code for a given secret, timestamp, period, and digits
    static func generateOTP(secret: String, time: Date = Date(), period: TimeInterval = 30, digits: Int = 6) -> String? {
        guard let keyData = decodeBase32(secret) else { return nil }
        
        let timeInterval = time.timeIntervalSince1970
        guard timeInterval >= 0, period > 0 else { return nil }
        
        let counter = UInt64(floor(timeInterval / period))
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: MemoryLayout<UInt64>.size)

        let symmetricKey = SymmetricKey(data: keyData)
        let mac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: symmetricKey)
        let hmacData = Data(mac)

        guard let lastByte = hmacData.last else { return nil }
        let offset = Int(lastByte & 0x0f)

        guard offset + 4 <= hmacData.count else { return nil }

        let truncatedHash = hmacData.subdata(in: offset..<offset+4)
        var number = truncatedHash.withUnsafeBytes { ptr -> UInt32 in
            return ptr.load(as: UInt32.self).bigEndian
        }

        number &= 0x7fffffff

        let modulus: UInt32
        switch digits {
        case 8: modulus = 100_000_000
        case 7: modulus = 10_000_000
        case 5: modulus = 100_000
        default: modulus = 1_000_000
        }

        let otpValue = number % modulus
        return String(format: "%0\(digits)d", otpValue)
    }

    /// Calculates remaining seconds in the current 30-second window
    static func timeRemaining(period: TimeInterval = 30) -> Int {
        let currentSeconds = Int(Date().timeIntervalSince1970)
        return Int(period) - (currentSeconds % Int(period))
    }

    /// Progress ratio from 0.0 to 1.0
    static func timeProgress(period: TimeInterval = 30) -> Double {
        return Double(timeRemaining(period: period)) / Double(period)
    }
}
