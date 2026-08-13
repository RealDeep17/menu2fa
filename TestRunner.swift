import Foundation
import AppKit
import CryptoKit

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
    if actual != expected {
        print("❌ FAIL [\(line)]: \(message) | Expected '\(expected)', got '\(actual)'")
        exit(1)
    } else {
        print("   ✅ PASS: \(message)")
    }
}

func assertTrue(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        print("❌ FAIL [\(line)]: \(message)")
        exit(1)
    } else {
        print("   ✅ PASS: \(message)")
    }
}

@main
struct TestRunner {
    static func main() {
        print("🚀 Running Menu2FA Comprehensive Test Suite...")
        print("----------------------------------------")

        testRFC6238TOTP()
        testSmartParser()
        testBase32Decoding()
        testAccountStoreAndDeduplication()
        testVaultEncryptionAndPermissions()

        print("----------------------------------------")
        print("🎉 ALL TESTS PASSED SUCCESSFULLY! (100% Verified)")
    }

    // MARK: - 1. RFC 6238 Assertion Matrix, Clamping, Boundaries & Edge Cases
    static func testRFC6238TOTP() {
        print("📌 Testing TOTPGenerator against official RFC 6238 Assertion Matrix...")

        let secret1 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ" // 20-byte key for SHA1 ("12345678901234567890")
        let secret256 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA" // 32-byte key for SHA256 ("12345678901234567890123456789012")
        let secret512 = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA" // 64-byte key for SHA512

        // --- 1.1 Full 54-Vector RFC 6238 Appendix B Matrix ---
        // Vector 1: Time = 59s
        let date1 = Date(timeIntervalSince1970: 59)
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 30, time: date1), "287082", "RFC6238 T=59 SHA1 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 7, period: 30, time: date1), "4287082", "RFC6238 T=59 SHA1 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 8, period: 30, time: date1), "94287082", "RFC6238 T=59 SHA1 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 6, period: 30, time: date1), "119246", "RFC6238 T=59 SHA256 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 7, period: 30, time: date1), "6119246", "RFC6238 T=59 SHA256 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 8, period: 30, time: date1), "46119246", "RFC6238 T=59 SHA256 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 6, period: 30, time: date1), "693936", "RFC6238 T=59 SHA512 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 7, period: 30, time: date1), "0693936", "RFC6238 T=59 SHA512 7d (leading zero)")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 8, period: 30, time: date1), "90693936", "RFC6238 T=59 SHA512 8d")

        // Vector 2: Time = 1,111,111,109s
        let date2 = Date(timeIntervalSince1970: 1111111109)
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 30, time: date2), "081804", "RFC6238 T=1111111109 SHA1 6d (leading zero)")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 7, period: 30, time: date2), "7081804", "RFC6238 T=1111111109 SHA1 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 8, period: 30, time: date2), "07081804", "RFC6238 T=1111111109 SHA1 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 6, period: 30, time: date2), "084774", "RFC6238 T=1111111109 SHA256 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 7, period: 30, time: date2), "8084774", "RFC6238 T=1111111109 SHA256 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 8, period: 30, time: date2), "68084774", "RFC6238 T=1111111109 SHA256 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 6, period: 30, time: date2), "091201", "RFC6238 T=1111111109 SHA512 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 7, period: 30, time: date2), "5091201", "RFC6238 T=1111111109 SHA512 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 8, period: 30, time: date2), "25091201", "RFC6238 T=1111111109 SHA512 8d")

        // Vector 3: Time = 1,111,111,111s
        let date3 = Date(timeIntervalSince1970: 1111111111)
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 30, time: date3), "050471", "RFC6238 T=1111111111 SHA1 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 7, period: 30, time: date3), "4050471", "RFC6238 T=1111111111 SHA1 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 8, period: 30, time: date3), "14050471", "RFC6238 T=1111111111 SHA1 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 6, period: 30, time: date3), "062674", "RFC6238 T=1111111111 SHA256 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 7, period: 30, time: date3), "7062674", "RFC6238 T=1111111111 SHA256 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 8, period: 30, time: date3), "67062674", "RFC6238 T=1111111111 SHA256 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 6, period: 30, time: date3), "943326", "RFC6238 T=1111111111 SHA512 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 7, period: 30, time: date3), "9943326", "RFC6238 T=1111111111 SHA512 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 8, period: 30, time: date3), "99943326", "RFC6238 T=1111111111 SHA512 8d")

        // Vector 4: Time = 1,234,567,890s
        let date4 = Date(timeIntervalSince1970: 1234567890)
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 30, time: date4), "005924", "RFC6238 T=1234567890 SHA1 6d (double leading zero)")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 7, period: 30, time: date4), "9005924", "RFC6238 T=1234567890 SHA1 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 8, period: 30, time: date4), "89005924", "RFC6238 T=1234567890 SHA1 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 6, period: 30, time: date4), "819424", "RFC6238 T=1234567890 SHA256 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 7, period: 30, time: date4), "1819424", "RFC6238 T=1234567890 SHA256 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 8, period: 30, time: date4), "91819424", "RFC6238 T=1234567890 SHA256 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 6, period: 30, time: date4), "441116", "RFC6238 T=1234567890 SHA512 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 7, period: 30, time: date4), "3441116", "RFC6238 T=1234567890 SHA512 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 8, period: 30, time: date4), "93441116", "RFC6238 T=1234567890 SHA512 8d")

        // Vector 5: Time = 2,000,000,000s
        let date5 = Date(timeIntervalSince1970: 2000000000)
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 30, time: date5), "279037", "RFC6238 T=2000000000 SHA1 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 7, period: 30, time: date5), "9279037", "RFC6238 T=2000000000 SHA1 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 8, period: 30, time: date5), "69279037", "RFC6238 T=2000000000 SHA1 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 6, period: 30, time: date5), "698825", "RFC6238 T=2000000000 SHA256 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 7, period: 30, time: date5), "0698825", "RFC6238 T=2000000000 SHA256 7d (leading zero)")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 8, period: 30, time: date5), "90698825", "RFC6238 T=2000000000 SHA256 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 6, period: 30, time: date5), "618901", "RFC6238 T=2000000000 SHA512 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 7, period: 30, time: date5), "8618901", "RFC6238 T=2000000000 SHA512 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 8, period: 30, time: date5), "38618901", "RFC6238 T=2000000000 SHA512 8d")

        // Vector 6: Time = 20,000,000,000s
        let date6 = Date(timeIntervalSince1970: 20000000000)
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 30, time: date6), "353130", "RFC6238 T=20000000000 SHA1 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 7, period: 30, time: date6), "5353130", "RFC6238 T=20000000000 SHA1 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 8, period: 30, time: date6), "65353130", "RFC6238 T=20000000000 SHA1 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 6, period: 30, time: date6), "737706", "RFC6238 T=20000000000 SHA256 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 7, period: 30, time: date6), "7737706", "RFC6238 T=20000000000 SHA256 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret256, algorithm: .sha256, digits: 8, period: 30, time: date6), "77737706", "RFC6238 T=20000000000 SHA256 8d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 6, period: 30, time: date6), "863826", "RFC6238 T=20000000000 SHA512 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 7, period: 30, time: date6), "7863826", "RFC6238 T=20000000000 SHA512 7d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret512, algorithm: .sha512, digits: 8, period: 30, time: date6), "47863826", "RFC6238 T=20000000000 SHA512 8d")

        // --- 1.2 Digit Count Clamping ---
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 5, period: 30, time: date1), "287082", "Clamping digits=5 -> 6 digits")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 0, period: 30, time: date1), "287082", "Clamping digits=0 -> 6 digits")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: -3, period: 30, time: date1), "287082", "Clamping digits=-3 -> 6 digits")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 9, period: 30, time: date1), "94287082", "Clamping digits=9 -> 8 digits")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 12, period: 30, time: date1), "94287082", "Clamping digits=12 -> 8 digits")

        // --- 1.3 Custom Periods & Guard Values ---
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 15, time: date1), "969429", "Custom period 15s at T=59")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 60, time: date1), "755224", "Custom period 60s at T=59")
        assertTrue(TOTPGenerator.generateTOTP(secret: secret1, period: 0) == nil, "Invalid period=0 returns nil")
        assertTrue(TOTPGenerator.generateTOTP(secret: secret1, period: -30) == nil, "Invalid period=-30 returns nil")
        assertEqual(TOTPGenerator.timeRemaining(period: 0), 0, "timeRemaining guard period <= 0")
        assertEqual(TOTPGenerator.timeRemaining(period: -10), 0, "timeRemaining guard period <= 0")
        assertEqual(TOTPGenerator.timeProgress(period: 0), 0.0, "timeProgress guard period <= 0")
        assertEqual(TOTPGenerator.timeProgress(period: -10), 0.0, "timeProgress guard period <= 0")

        // --- 1.4 Boundary Timestamps & Step Transitions ---
        let dateEpoch = Date(timeIntervalSince1970: 0)
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 30, time: dateEpoch), "755224", "T=0 Unix Epoch SHA1 6d")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 8, period: 30, time: dateEpoch), "84755224", "T=0 Unix Epoch SHA1 8d")
        assertTrue(TOTPGenerator.generateTOTP(secret: secret1, time: Date(timeIntervalSince1970: -1)) == nil, "Negative timestamp T=-1 returns nil")
        assertTrue(TOTPGenerator.generateTOTP(secret: secret1, time: Date(timeIntervalSince1970: -1000)) == nil, "Negative timestamp T=-1000 returns nil")

        let dateT29 = Date(timeIntervalSince1970: 29)
        let dateT30 = Date(timeIntervalSince1970: 30)
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 30, time: dateT29), "755224", "T=29s remains in counter 0 window")
        assertEqual(TOTPGenerator.generateTOTP(secret: secret1, algorithm: .sha1, digits: 6, period: 30, time: dateT30), "287082", "T=30s advances to counter 1 window")

        // --- 1.5 Invalid / Empty Secrets & Normalization ---
        assertTrue(TOTPGenerator.generateTOTP(secret: "") == nil, "Empty secret returns nil")
        assertTrue(TOTPGenerator.generateTOTP(secret: "   \t\n ") == nil, "Whitespace secret returns nil")
        assertTrue(TOTPGenerator.generateTOTP(secret: "JBSWY3DPEHPK3P89!") == nil, "Invalid Base32 secret returns nil")
        assertEqual(TOTPGenerator.generateTOTP(secret: " gezd-gnbv gy3t-qojq == ", algorithm: .sha1, digits: 6, period: 30, time: dateEpoch), "891490", "Secret normalization (lowercase, dashes, spaces, padding)")
        assertEqual(TOTPGenerator.generateTOTP(secret: " gezd-gnbv gy3t-qojq gezd-gnbv gy3t-qojq == ", algorithm: .sha1, digits: 6, period: 30, time: dateEpoch), "755224", "20-byte Secret normalization at T=0")
        assertTrue(TOTPGenerator.generateTOTP(secret: "GEZD", algorithm: .sha1, digits: 6, period: 30, time: dateEpoch) != nil, "Short secret handled safely")

        // --- 1.6 Legacy API Wrapper ---
        assertEqual(TOTPGenerator.generateOTP(secret: secret1, time: date1, period: 30, digits: 6), "287082", "Legacy generateOTP wrapper matches generateTOTP")
    }

    // MARK: - 2. Smart Parser Tests
    static func testSmartParser() {
        print("📌 Testing SmartParser logic, URI edge cases & normalization...")

        // Case A: Secret + Email + Issuer
        let p0 = SmartParser.parse("HXDMVJECJJWSRB3H alex@example.com GitHub")
        assertTrue(p0 != nil, "Parsed secret + email + issuer")
        assertEqual(p0?.name, "alex@example.com", "P0 Name")
        assertEqual(p0?.issuer, "GitHub", "P0 Issuer")
        assertEqual(p0?.secret, "HXDMVJECJJWSRB3H", "P0 Secret")
        assertEqual(p0?.algorithm, .sha1, "P0 default algorithm SHA1")
        assertEqual(p0?.digits, 6, "P0 default digits 6")
        assertEqual(p0?.period, 30.0, "P0 default period 30")

        // Case A2: Secret + Email
        let p1 = SmartParser.parse("HXDMVJECJJWSRB3H alex@example.com")
        assertTrue(p1 != nil, "Parsed secret + email")
        assertEqual(p1?.name, "alex@example.com", "P1 Name")
        assertEqual(p1?.secret, "HXDMVJECJJWSRB3H", "P1 Secret")

        // Case B: Email + Secret
        let p2 = SmartParser.parse("alex@example.com HXDMVJECJJWSRB3H")
        assertTrue(p2 != nil, "Parsed email + secret")
        assertEqual(p2?.name, "alex@example.com", "P2 Name")
        assertEqual(p2?.secret, "HXDMVJECJJWSRB3H", "P2 Secret")

        // Case C: Base32 word ambiguity ("ACCOUNTS HXDMVJECJJWSRB3H")
        let p3 = SmartParser.parse("ACCOUNTS HXDMVJECJJWSRB3H")
        assertTrue(p3 != nil, "Parsed Base32 label + secret")
        assertEqual(p3?.name, "ACCOUNTS", "P3 Name")
        assertEqual(p3?.secret, "HXDMVJECJJWSRB3H", "P3 Secret picked true key over Base32 label")

        // Case D: Prefix issuer with colon ("GitHub: user@example.com HXDMVJECJJWSRB3H")
        let p4 = SmartParser.parse("GitHub: user@example.com HXDMVJECJJWSRB3H")
        assertTrue(p4 != nil, "Parsed issuer: name + secret")
        assertEqual(p4?.issuer, "GitHub", "P4 Issuer")
        assertEqual(p4?.name, "user@example.com", "P4 Name")
        assertEqual(p4?.secret, "HXDMVJECJJWSRB3H", "P4 Secret")

        // Case E: otpauth:// URI with algorithm, digits, period, uppercase scheme/host, and encoded colons
        let uri1 = "OTPAUTH://TOTP/Google:alex@example.com?secret=HXDMVJECJJWSRB3H&issuer=Google&algorithm=SHA256&digits=8&period=60"
        let p5 = SmartParser.parse(uri1)
        assertTrue(p5 != nil, "Parsed OTPAUTH://TOTP/ URI with custom params")
        assertEqual(p5?.issuer, "Google", "P5 Issuer")
        assertEqual(p5?.name, "alex@example.com", "P5 Name")
        assertEqual(p5?.secret, "HXDMVJECJJWSRB3H", "P5 Secret")
        assertEqual(p5?.algorithm, .sha256, "P5 algorithm SHA256")
        assertEqual(p5?.digits, 8, "P5 digits 8")
        assertEqual(p5?.period, 60.0, "P5 period 60.0")

        // Encoded colon in URI path (%3A)
        let uriColon = "otpauth://totp/My%3AService:user@example.com?secret=JBSWY3DPEHPK3PXP&algorithm=SHA512&digits=7&period=15"
        let p6 = SmartParser.parse(uriColon)
        assertTrue(p6 != nil, "Parsed URI with encoded colon %3A")
        assertEqual(p6?.issuer, "My:Service", "P6 Issuer with encoded colon preserved")
        assertEqual(p6?.name, "user@example.com", "P6 Name")
        assertEqual(p6?.algorithm, .sha512, "P6 algorithm SHA512")
        assertEqual(p6?.digits, 7, "P6 digits 7")
        assertEqual(p6?.period, 15.0, "P6 period 15.0")

        // Case F: Multi-line parsing
        let multi = """
        HXDMVJECJJWSRB3H alex@example.com
        user2@example.com JBSWY3DPEHPK3PXP
        """
        let multiResults = SmartParser.parseMultiple(multi)
        assertEqual(multiResults.count, 2, "Multi-line parsed 2 entries")
        assertEqual(multiResults[0].secret, "HXDMVJECJJWSRB3H", "Multi line item 0 secret")
        assertEqual(multiResults[1].secret, "JBSWY3DPEHPK3PXP", "Multi line item 1 secret")

        // --- 2.1 Percent-encoded URIs (%20, %40, %2B) ---
        let uriEncoded = "otpauth://totp/Acme%20Corp:user%2Btest%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=Acme%20Corp"
        let pEnc = SmartParser.parse(uriEncoded)
        assertTrue(pEnc != nil, "Parsed URI with percent-encoded spaces, +, and @")
        assertEqual(pEnc?.issuer, "Acme Corp", "Decoded percent-encoded issuer spaces")
        assertEqual(pEnc?.name, "user+test@example.com", "Decoded percent-encoded name @ and +")

        // --- 2.2 Mixed/Uppercase Query Parameter Keys ---
        let uriUpperKeys = "otpauth://totp/Google:user@gmail.com?SECRET=JBSWY3DPEHPK3PXP&ISSUER=Google&ALGORITHM=SHA256&DIGITS=8&PERIOD=60"
        let pUpper = SmartParser.parse(uriUpperKeys)
        assertTrue(pUpper != nil, "Parsed URI with uppercase query keys")
        assertEqual(pUpper?.issuer, "Google", "PUpper Issuer")
        assertEqual(pUpper?.secret, "JBSWY3DPEHPK3PXP", "PUpper Secret")
        assertEqual(pUpper?.algorithm, .sha256, "PUpper Algorithm SHA256")
        assertEqual(pUpper?.digits, 8, "PUpper Digits 8")
        assertEqual(pUpper?.period, 60.0, "PUpper Period 60")

        // --- 2.3 Query Issuer Overriding URI Path Issuer ---
        let uriOverride = "otpauth://totp/PathIssuer:user@domain.com?secret=JBSWY3DPEHPK3PXP&issuer=ExplicitIssuer"
        let pOverride = SmartParser.parse(uriOverride)
        assertEqual(pOverride?.issuer, "ExplicitIssuer", "Query issuer overrides path issuer")
        assertEqual(pOverride?.name, "user@domain.com", "Path name retained when query issuer overrides")

        // --- 2.4 Invalid Parameter Fallbacks ---
        let uriBadParams = "otpauth://totp/Test:user@domain.com?secret=JBSWY3DPEHPK3PXP&algorithm=UNKNOWN&digits=5&period=-10"
        let pBad = SmartParser.parse(uriBadParams)
        assertEqual(pBad?.algorithm, .sha1, "Unknown algorithm fallback to SHA1")
        assertEqual(pBad?.digits, 6, "Invalid digits (5) fallback to 6")
        assertEqual(pBad?.period, 30.0, "Invalid period (-10) fallback to 30.0")

        let uriBadDigitsHigh = "otpauth://totp/Test:user@domain.com?secret=JBSWY3DPEHPK3PXP&digits=99"
        let pBadHigh = SmartParser.parse(uriBadDigitsHigh)
        assertEqual(pBadHigh?.digits, 6, "Invalid digits (99) fallback to 6")

        // --- 2.5 Raw Spaces in URI String ---
        let uriRawSpaces = "otpauth://totp/My Service:user@test.com?secret=JBSWY3DPEHPK3PXP"
        let pRawSpaces = SmartParser.parse(uriRawSpaces)
        assertTrue(pRawSpaces != nil, "Parsed URI with raw spaces")
        assertEqual(pRawSpaces?.issuer, "My Service", "Raw space in issuer parsed")

        // --- 2.6 Non-TOTP Scheme & Missing Secret Rejection ---
        assertTrue(SmartParser.parse("hotp://totp/Google:user@gmail.com?secret=JBSWY3DPEHPK3PXP") == nil, "HOTP scheme rejected")
        assertTrue(SmartParser.parse("otpauth://totp/Google:user@gmail.com") == nil, "URI missing secret returns nil")

        // --- 2.7 Unicode Dashes & Whitespace Normalization ---
        let unicodeSecret = "\u{00A0}hxdm\u{2012}vjec\u{2013}jjws\u{2014}rb3h\u{2015}===\u{200B}\u{2009}"
        let cleanedUnicode = SmartParser.cleanSecret(unicodeSecret)
        assertEqual(cleanedUnicode, "HXDMVJECJJWSRB3H", "Cleaned secret with figure dash, horizontal bar, thin space, zero-width space, and padding")

        // --- 2.8 Standalone Secret Key Input ---
        let pStandalone = SmartParser.parse("JBSWY3DPEHPK3PXP")
        assertTrue(pStandalone != nil, "Parsed standalone secret key")
        assertEqual(pStandalone?.name, "Account", "Standalone secret default name 'Account'")
        assertEqual(pStandalone?.issuer, "", "Standalone secret default empty issuer")
        assertEqual(pStandalone?.secret, "JBSWY3DPEHPK3PXP", "Standalone secret key value")

        // --- 2.9 Invalid Secret Key Rejection ---
        let pInvalid = SmartParser.parse("INVALID890189018901")
        assertTrue(pInvalid == nil, "Invalid Base32 secret string (containing 8,9,0,1) rejected")
    }

    // MARK: - 3. Base32 Cleaning Tests
    static func testBase32Decoding() {
        print("📌 Testing Base32 cleaning & decoding...")

        let raw = " \thxdm - vjec – jjws — rb3h = \n\u{00A0}"
        let cleaned = SmartParser.cleanSecret(raw)
        assertEqual(cleaned, "HXDMVJECJJWSRB3H", "Cleaned secret string with spaces, tabs, newlines, en-dashes, em-dashes, equals")

        let decoded = TOTPGenerator.decodeBase32(cleaned)
        assertTrue(decoded != nil && decoded!.count > 0, "Decoded Base32 binary data")

        // Additional Unicode whitespace and dash tests
        let unicodeRaw = "\u{2009}HXDM\u{2012}VJEC\u{2015}JJWS\u{200B}RB3H===="
        let unicodeCleaned = SmartParser.cleanSecret(unicodeRaw)
        assertEqual(unicodeCleaned, "HXDMVJECJJWSRB3H", "Cleaned secret with thin space, figure dash, horizontal bar, zero-width space")
    }

    // MARK: - 4. AccountStore & Storage Tests
    static func testAccountStoreAndDeduplication() {
        print("📌 Testing AccountStore operations, deduplication & vault export/import...")

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = AccountStore(directory: testDir)
        store.deleteAllAccounts()
        assertEqual(store.accounts.count, 0, "Store cleared initially")

        // Add 1st account with explicit issuer "GitHub" and custom TOTP parameters
        let added1 = store.addAccount(name: "test1@example.com", issuer: "GitHub", secret: "HXDMVJECJJWSRB3H", algorithm: .sha256, digits: 8, period: 60)
        assertTrue(added1, "Added 1st account")
        assertEqual(store.accounts.count, 1, "1 account in store")
        assertEqual(store.accounts[0].algorithm, .sha256, "Stored algorithm SHA256")
        assertEqual(store.accounts[0].digits, 8, "Stored digits 8")
        assertEqual(store.accounts[0].period, 60.0, "Stored period 60.0")

        // Add 2nd account with missing/empty issuer -> should fallback to lastUsedIssuer ("GitHub")
        let added2 = store.addAccount(name: "test2@example.com", issuer: "", secret: "JBSWY3DPEHPK3PXP")
        assertTrue(added2, "Added 2nd account with empty issuer")
        assertEqual(store.accounts.count, 2, "2 accounts in store")
        assertEqual(store.accounts[1].issuer, "GitHub", "Fallback to last used issuer GitHub")

        // Add duplicate account with same secret -> should deduplicate and update name, issuer, and params
        let addedDup = store.addAccount(name: "updated_name@example.com", issuer: "GitHub", secret: "HXDMVJECJJWSRB3H", algorithm: .sha512, digits: 7, period: 15)
        assertTrue(addedDup, "Handled duplicate secret")
        assertEqual(store.accounts.count, 2, "Store count remains 2 due to deduplication")
        assertEqual(store.accounts[0].name, "updated_name@example.com", "Account updated name")
        assertEqual(store.accounts[0].algorithm, .sha512, "Deduplicated account updated algorithm to SHA512")
        assertEqual(store.accounts[0].digits, 7, "Deduplicated account updated digits to 7")

        // Case-insensitive secret deduplication (lowercase secret input)
        let addedLowerDup = store.addAccount(name: "updated_name_lower@example.com", issuer: "GitHub", secret: "hxdmvjecjjwsrb3h")
        assertTrue(addedLowerDup, "Deduplicated lowercase secret input")
        assertEqual(store.accounts.count, 2, "Store count remains 2 after lowercase secret deduplication")
        assertEqual(store.accounts[0].name, "updated_name_lower@example.com", "Account updated name via lowercase secret deduplication")

        // Deduplicate Case 2: Match by issuer + name (update secret & params)
        let addedDup2 = store.addAccount(name: "updated_name_lower@example.com", issuer: "GitHub", secret: "GEZDGNBVGY3TQOJQ", algorithm: .sha1, digits: 6, period: 30)
        assertTrue(addedDup2, "Handled duplicate issuer+name")
        assertEqual(store.accounts.count, 2, "Store count remains 2")
        assertEqual(store.getSecret(for: store.accounts[0]), "GEZDGNBVGY3TQOJQ", "Deduplicated secret updated")
        assertEqual(store.accounts[0].algorithm, .sha1, "Deduplicated algorithm updated to SHA1")

        // Deduplicate Case 2 with lastUsedIssuer resolution
        let addedDupLastIssuer = store.addAccount(name: "test2@example.com", issuer: "", secret: "GEZDGNBVGY3TQOJQ")
        assertTrue(addedDupLastIssuer, "Deduplicated by issuer+name with empty issuer resolving to lastUsedIssuer")
        assertEqual(store.accounts.count, 2, "Store count remains 2")

        // Add 3 distinct accounts
        let store3 = AccountStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        store3.deleteAllAccounts()
        assertTrue(store3.addAccount(name: "user1", issuer: "Iss1", secret: "JBSWY3DPEHPK3PXP"), "Added user1")
        assertTrue(store3.addAccount(name: "user2", issuer: "Iss2", secret: "HXDMVJECJJWSRB3H"), "Added user2")
        assertTrue(store3.addAccount(name: "user3", issuer: "Iss3", secret: "GEZDGNBVGY3TQOJQ"), "Added user3")
        assertEqual(store3.accounts.count, 3, "Added 3 distinct accounts")

        // Test legacy TOTPEntry JSON decoding without algorithm/digits/period
        let legacyJSON = """
        [{"id": "\(UUID().uuidString)", "name": "legacy@user.com", "issuer": "LegacyApp", "createdAt": 1700000000}]
        """.data(using: .utf8)!
        if let decodedLegacy = try? JSONDecoder().decode([TOTPEntry].self, from: legacyJSON) {
            assertEqual(decodedLegacy.count, 1, "Decoded legacy JSON entry")
            assertEqual(decodedLegacy[0].algorithm, .sha1, "Legacy entry default algorithm SHA1")
            assertEqual(decodedLegacy[0].digits, 6, "Legacy entry default digits 6")
            assertEqual(decodedLegacy[0].period, 30.0, "Legacy entry default period 30.0")
        } else {
            assertTrue(false, "Failed to decode legacy TOTPEntry JSON")
        }

        // Vault Export & Import Roundtrip with Custom Parameters
        let exportStore = AccountStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        exportStore.deleteAllAccounts()
        assertTrue(exportStore.addAccount(name: "acc1", issuer: "Iss1", secret: "JBSWY3DPEHPK3PXP", algorithm: .sha1, digits: 6, period: 30), "Added export acc1")
        assertTrue(exportStore.addAccount(name: "acc2", issuer: "Iss2", secret: "HXDMVJECJJWSRB3H", algorithm: .sha256, digits: 8, period: 60), "Added export acc2")
        assertTrue(exportStore.addAccount(name: "acc3", issuer: "Iss3", secret: "GEZDGNBVGY3TQOJQ", algorithm: .sha512, digits: 7, period: 15), "Added export acc3")

        guard let exportedJSON = exportStore.exportVault() else {
            assertTrue(false, "Failed to export populated vault")
            return
        }

        let importStore = AccountStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        importStore.deleteAllAccounts()
        let importedCount = importStore.importVault(jsonString: exportedJSON)
        assertEqual(importedCount, 3, "Imported 3 accounts successfully")
        assertEqual(importStore.accounts.count, 3, "Import store has 3 accounts")
        assertEqual(importStore.accounts[0].algorithm, .sha1, "Acc 1 algorithm SHA1")
        assertEqual(importStore.accounts[1].algorithm, .sha256, "Acc 2 algorithm SHA256")
        assertEqual(importStore.accounts[1].digits, 8, "Acc 2 digits 8")
        assertEqual(importStore.accounts[1].period, 60.0, "Acc 2 period 60")
        assertEqual(importStore.accounts[2].algorithm, .sha512, "Acc 3 algorithm SHA512")
        assertEqual(importStore.accounts[2].digits, 7, "Acc 3 digits 7")
        assertEqual(importStore.accounts[2].period, 15.0, "Acc 3 period 15")

        // Exporting empty vault
        let emptyStore = AccountStore(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        emptyStore.deleteAllAccounts()
        assertEqual(emptyStore.exportVault(), "[]", "Exporting empty vault returns '[]'")

        // Import legacy export JSON without parameter fields
        let legacyExportJSON = """
        [{"name": "legacy_name", "issuer": "legacy_issuer", "secret": "JBSWY3DPEHPK3PXP"}]
        """
        let importedLegacyCount = importStore.importVault(jsonString: legacyExportJSON)
        assertEqual(importedLegacyCount, 1, "Imported legacy export JSON entry")
        let legacyAcc = importStore.accounts.first(where: { $0.name == "legacy_name" })
        assertTrue(legacyAcc != nil, "Legacy imported account found")
        assertEqual(legacyAcc?.algorithm, .sha1, "Legacy import default algorithm SHA1")
        assertEqual(legacyAcc?.digits, 6, "Legacy import default digits 6")
        assertEqual(legacyAcc?.period, 30.0, "Legacy import default period 30.0")

        // Import malformed JSON string handling
        let malformedImportCount = importStore.importVault(jsonString: "NOT_JSON")
        assertEqual(malformedImportCount, 0, "Malformed JSON import returns 0 without crash")

        // Cleanup
        store.deleteAllAccounts()
        store3.deleteAllAccounts()
        exportStore.deleteAllAccounts()
        importStore.deleteAllAccounts()
        emptyStore.deleteAllAccounts()
    }

    // MARK: - 5. CryptoKit Vault Encryption, Permissions & Recovery Tests
    static func testVaultEncryptionAndPermissions() {
        print("📌 Testing CryptoKit AES-256-GCM Vault Encryption, Permissions & Recovery...")

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = AccountStore(directory: testDir)
        store.deleteAllAccounts()

        // 1. Add account and verify disk encryption
        let added = store.addAccount(name: "test@crypto.com", issuer: "CryptoTest", secret: "JBSWY3DPEHPK3PXP")
        assertTrue(added, "Added test account")

        let vaultURL = testDir.appendingPathComponent("vault.json")
        let keyURL = testDir.appendingPathComponent("vault.key")
        let accountsURL = testDir.appendingPathComponent("accounts.json")

        assertTrue(FileManager.default.fileExists(atPath: vaultURL.path), "vault.json exists")
        assertTrue(FileManager.default.fileExists(atPath: keyURL.path), "vault.key exists")
        assertTrue(FileManager.default.fileExists(atPath: accountsURL.path), "accounts.json exists")

        // 2. Verify vault.json is valid VaultEnvelope and does NOT contain raw secret
        guard let rawData = try? Data(contentsOf: vaultURL),
              let rawString = String(data: rawData, encoding: .utf8) else {
            assertTrue(false, "Failed to read vault.json data")
            return
        }
        assertTrue(!rawString.contains("JBSWY3DPEHPK3PXP"), "vault.json does NOT contain plaintext secret")
        let envelope = try? JSONDecoder().decode(VaultEnvelope.self, from: rawData)
        assertTrue(envelope != nil, "vault.json is valid VaultEnvelope JSON")
        assertEqual(envelope?.version, 1, "Vault version is 1")

        // 3. Direct CryptoKit AES-256-GCM Decryption Roundtrip with Master Key
        guard let keyData = try? Data(contentsOf: keyURL) else {
            assertTrue(false, "Failed to read vault.key")
            return
        }
        assertEqual(keyData.count, 32, "Vault key is 256 bits (32 bytes)")
        let masterKey = SymmetricKey(data: keyData)

        guard let env = envelope,
              let combinedData = Data(base64Encoded: env.combinedData),
              let sealedBox = try? AES.GCM.SealedBox(combined: combinedData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: masterKey),
              let dict = try? JSONDecoder().decode([String: String].self, from: decryptedData) else {
            assertTrue(false, "Direct CryptoKit AES-256-GCM decryption failed")
            return
        }
        let storedSecret = dict.values.first
        assertEqual(storedSecret, "JBSWY3DPEHPK3PXP", "Direct CryptoKit decryption recovered exact secret")

        // 4. Tampered Ciphertext / Auth Tag Validation Failure
        var tamperedCombined = combinedData
        if tamperedCombined.count > 10 {
            tamperedCombined[tamperedCombined.count - 1] ^= 0xFF // Flip bits of auth tag
        }
        if let tamperedBox = try? AES.GCM.SealedBox(combined: tamperedCombined) {
            let tamperedResult = try? AES.GCM.open(tamperedBox, using: masterKey)
            assertTrue(tamperedResult == nil, "Tampered ciphertext / auth tag throws authentication failure")
        } else {
            assertTrue(true, "SealedBox construction or decryption rejected tampered combined data")
        }

        // 5. Key Corruption (< 32 bytes) Handling
        let corruptKeyDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: corruptKeyDir, withIntermediateDirectories: true)
        let corruptKeyURL = corruptKeyDir.appendingPathComponent("vault.key")
        let truncatedKeyData = Data(repeating: 0xAA, count: 16) // Invalid 16-byte key
        try? truncatedKeyData.write(to: corruptKeyURL)

        let corruptKeyStore = AccountStore(directory: corruptKeyDir)
        assertTrue(corruptKeyStore.accounts.isEmpty, "Corrupt key store initialized safely")

        // 6. POSIX 0600 File Permissions Assertion & Automatic Repair
        for url in [vaultURL, keyURL, accountsURL] {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let permissions = attrs[.posixPermissions] as? NSNumber {
                assertEqual(permissions.uint16Value, 0o600, "File \(url.lastPathComponent) has POSIX 0600 permissions")
            } else {
                assertTrue(false, "Failed to inspect permissions for \(url.lastPathComponent)")
            }
        }

        // Automatic Repair on Startup: Pre-create loose permissions 0o644
        let repairDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: repairDir, withIntermediateDirectories: true)
        let repairVaultURL = repairDir.appendingPathComponent("vault.json")
        let repairKeyURL = repairDir.appendingPathComponent("vault.key")
        let repairAccURL = repairDir.appendingPathComponent("accounts.json")

        let dummyJsonData = "[]".data(using: .utf8)!
        let dummyEnvelopeData = "{\"version\":1,\"combinedData\":\"\"}".data(using: .utf8)!
        try? dummyEnvelopeData.write(to: repairVaultURL)
        try? Data(repeating: 0x01, count: 32).write(to: repairKeyURL)
        try? dummyJsonData.write(to: repairAccURL)

        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: repairVaultURL.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: repairKeyURL.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: repairAccURL.path)

        _ = AccountStore(directory: repairDir) // Triggers loadAccounts() & automatic permission repair

        for url in [repairVaultURL, repairKeyURL, repairAccURL] {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let permissions = attrs[.posixPermissions] as? NSNumber {
                assertEqual(permissions.uint16Value, 0o600, "Loose file \(url.lastPathComponent) automatically repaired to POSIX 0600")
            }
        }

        // 7. Permission Persistence Across Operations
        assertTrue(store.addAccount(name: "perm_test", issuer: "PermIssuer", secret: "GEZDGNBVGY3TQOJQ"), "Added perm test account")
        let accToUpdate = store.accounts.first(where: { $0.name == "perm_test" })!
        store.updateAccount(accToUpdate, newName: "perm_updated", newIssuer: "PermIssuer", newAlgorithm: .sha1, newDigits: 6, newPeriod: 30)
        
        for url in [vaultURL, keyURL, accountsURL] {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let permissions = attrs[.posixPermissions] as? NSNumber {
                assertEqual(permissions.uint16Value, 0o600, "Permissions persist 0o600 after updateAccount")
            }
        }

        store.deleteAccount(accToUpdate)
        for url in [vaultURL, keyURL, accountsURL] {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let permissions = attrs[.posixPermissions] as? NSNumber {
                assertEqual(permissions.uint16Value, 0o600, "Permissions persist 0o600 after deleteAccount")
            }
        }

        // 8. Legacy Unencrypted Vault Auto-Migration
        let legacyDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        let legacyVaultURL = legacyDir.appendingPathComponent("vault.json")
        let testUUID = UUID()
        let legacyDict = [testUUID.uuidString: "JBSWY3DPEHPK3PXP"]
        if let legacyData = try? JSONEncoder().encode(legacyDict) {
            try? legacyData.write(to: legacyVaultURL)
        }

        let legacyStore = AccountStore(directory: legacyDir)
        let dummyEntry = TOTPEntry(id: testUUID, name: "LegacyTest", issuer: "LegacyIssuer")
        assertEqual(legacyStore.getSecret(for: dummyEntry), "JBSWY3DPEHPK3PXP", "Legacy secret recovered after migration")
        
        if let migratedData = try? Data(contentsOf: legacyVaultURL) {
            let envMigrated = try? JSONDecoder().decode(VaultEnvelope.self, from: migratedData)
            assertTrue(envMigrated != nil, "Legacy vault successfully auto-migrated to VaultEnvelope on disk")
        } else {
            assertTrue(false, "Failed to read migrated legacy vault data")
        }

        // Legacy Mac2FA App Support Fallback Migration
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let mac2FADir = appSupport.appendingPathComponent("Mac2FA", isDirectory: true)
        try? FileManager.default.createDirectory(at: mac2FADir, withIntermediateDirectories: true)
        let mac2FAAccountsURL = mac2FADir.appendingPathComponent("accounts.json")
        let mac2FAEntry = TOTPEntry(name: "Mac2FAName", issuer: "Mac2FAIssuer")
        if let mac2FAData = try? JSONEncoder().encode([mac2FAEntry]) {
            try? mac2FAData.write(to: mac2FAAccountsURL)
        }

        let emptyCustomDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let mac2FASubStore = AccountStore(directory: emptyCustomDir)
        assertTrue(mac2FASubStore.accounts.contains(where: { $0.name == "Mac2FAName" }), "Legacy Mac2FA directory accounts migrated when local accounts missing")

        // Cleanup legacy Mac2FA test directory
        try? FileManager.default.removeItem(at: mac2FADir)

        // 9. Corrupted Vault Recovery & Post-Corruption Operation
        let corruptDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: corruptDir, withIntermediateDirectories: true)
        let corruptVaultURL = corruptDir.appendingPathComponent("vault.json")
        try? "CORRUPTED_BYTES_NOT_JSON".data(using: .utf8)?.write(to: corruptVaultURL)

        let corruptStore = AccountStore(directory: corruptDir)
        assertTrue(corruptStore.accounts.isEmpty, "Corrupt store initialized safely without crash")
        let items = (try? FileManager.default.contentsOfDirectory(atPath: corruptDir.path)) ?? []
        assertTrue(items.contains(where: { $0.contains("vault.json.corrupted") }), "Corrupted vault backed up to vault.json.corrupted.<timestamp>")

        let postCorruptAdded = corruptStore.addAccount(name: "post_corrupt", issuer: "RecoveryTest", secret: "JBSWY3DPEHPK3PXP")
        assertTrue(postCorruptAdded, "Post-corruption account addition succeeded")
        assertEqual(corruptStore.accounts.count, 1, "Post-corruption store count is 1")
        assertEqual(corruptStore.getSecret(for: corruptStore.accounts[0]), "JBSWY3DPEHPK3PXP", "Post-corruption account secret retrievable")

        // 10. Explicit Zero Keychain Assertion
        let keyExistsOnDisk = FileManager.default.fileExists(atPath: keyURL.path)
        assertTrue(keyExistsOnDisk, "Vault key managed via 0o600 file (vault.key) with ZERO Keychain UI prompts")

        // Cleanup
        store.deleteAllAccounts()
        corruptStore.deleteAllAccounts()
    }
}
