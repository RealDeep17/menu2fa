import Foundation
import AppKit
import CoreImage

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
        print("🚀 Running Menu2FA Test Suite...")
        print("----------------------------------------")

        testRFC6238TOTP()
        testSmartParser()
        testBase32Decoding()
        testAccountStoreAndDeduplication()

        print("----------------------------------------")
        print("🎉 ALL TESTS PASSED SUCCESSFULLY! (100% Verified)")
    }

    // MARK: - 1. RFC 6238 Test Vectors
    static func testRFC6238TOTP() {
        print("📌 Testing TOTPGenerator against official RFC 6238 Test Vectors...")
        let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ" // ASCII "12345678901234567890"

        // Vector 1: Time = 59s
        let date1 = Date(timeIntervalSince1970: 59)
        let otp1_8 = TOTPGenerator.generateOTP(secret: secret, time: date1, period: 30, digits: 8)
        let otp1_6 = TOTPGenerator.generateOTP(secret: secret, time: date1, period: 30, digits: 6)
        assertEqual(otp1_8, "94287082", "RFC 6238 T=59 (8 digits)")
        assertEqual(otp1_6, "287082", "RFC 6238 T=59 (6 digits)")

        // Vector 2: Time = 1,111,111,109s
        let date2 = Date(timeIntervalSince1970: 1111111109)
        let otp2_8 = TOTPGenerator.generateOTP(secret: secret, time: date2, period: 30, digits: 8)
        let otp2_6 = TOTPGenerator.generateOTP(secret: secret, time: date2, period: 30, digits: 6)
        assertEqual(otp2_8, "07081804", "RFC 6238 T=1111111109 (8 digits)")
        assertEqual(otp2_6, "081804", "RFC 6238 T=1111111109 (6 digits)")

        // Vector 3: Time = 1,111,111,111s
        let date3 = Date(timeIntervalSince1970: 1111111111)
        let otp3_8 = TOTPGenerator.generateOTP(secret: secret, time: date3, period: 30, digits: 8)
        let otp3_6 = TOTPGenerator.generateOTP(secret: secret, time: date3, period: 30, digits: 6)
        assertEqual(otp3_8, "14050471", "RFC 6238 T=1111111111 (8 digits)")
        assertEqual(otp3_6, "050471", "RFC 6238 T=1111111111 (6 digits)")

        // Vector 4: Time = 1,234,567,890s
        let date4 = Date(timeIntervalSince1970: 1234567890)
        let otp4_8 = TOTPGenerator.generateOTP(secret: secret, time: date4, period: 30, digits: 8)
        let otp4_6 = TOTPGenerator.generateOTP(secret: secret, time: date4, period: 30, digits: 6)
        assertEqual(otp4_8, "89005924", "RFC 6238 T=1234567890 (8 digits)")
        assertEqual(otp4_6, "005924", "RFC 6238 T=1234567890 (6 digits)")

        // Vector 5: Time = 2,000,000,000s
        let date5 = Date(timeIntervalSince1970: 2000000000)
        let otp5_8 = TOTPGenerator.generateOTP(secret: secret, time: date5, period: 30, digits: 8)
        let otp5_6 = TOTPGenerator.generateOTP(secret: secret, time: date5, period: 30, digits: 6)
        assertEqual(otp5_8, "69279037", "RFC 6238 T=2000000000 (8 digits)")
        assertEqual(otp5_6, "279037", "RFC 6238 T=2000000000 (6 digits)")
    }

    // MARK: - 2. Smart Parser Tests
    static func testSmartParser() {
        print("📌 Testing SmartParser logic & ambiguity resolution...")

        // Case A: Secret + Email + Issuer
        let p0 = SmartParser.parse("4DM2M47UQISBDUHV vasilolein54@gmail.com GitHub")
        assertTrue(p0 != nil, "Parsed secret + email + issuer")
        assertEqual(p0?.name, "vasilolein54@gmail.com", "P0 Name")
        assertEqual(p0?.issuer, "GitHub", "P0 Issuer")
        assertEqual(p0?.secret, "4DM2M47UQISBDUHV", "P0 Secret")

        // Case A2: Secret + Email
        let p1 = SmartParser.parse("4DM2M47UQISBDUHV vasilolein54@gmail.com")
        assertTrue(p1 != nil, "Parsed secret + email")
        assertEqual(p1?.name, "vasilolein54@gmail.com", "P1 Name")
        assertEqual(p1?.secret, "4DM2M47UQISBDUHV", "P1 Secret")

        // Case B: Email + Secret
        let p2 = SmartParser.parse("vasilolein54@gmail.com 4DM2M47UQISBDUHV")
        assertTrue(p2 != nil, "Parsed email + secret")
        assertEqual(p2?.name, "vasilolein54@gmail.com", "P2 Name")
        assertEqual(p2?.secret, "4DM2M47UQISBDUHV", "P2 Secret")

        // Case C: Base32 word ambiguity ("ACCOUNTS 4DM2M47UQISBDUHV")
        let p3 = SmartParser.parse("ACCOUNTS 4DM2M47UQISBDUHV")
        assertTrue(p3 != nil, "Parsed Base32 label + secret")
        assertEqual(p3?.name, "ACCOUNTS", "P3 Name")
        assertEqual(p3?.secret, "4DM2M47UQISBDUHV", "P3 Secret picked true key over Base32 label")

        // Case D: Prefix issuer with colon ("GitHub: user@example.com 4DM2M47UQISBDUHV")
        let p4 = SmartParser.parse("GitHub: user@example.com 4DM2M47UQISBDUHV")
        assertTrue(p4 != nil, "Parsed issuer: name + secret")
        assertEqual(p4?.issuer, "GitHub", "P4 Issuer")
        assertEqual(p4?.name, "user@example.com", "P4 Name")
        assertEqual(p4?.secret, "4DM2M47UQISBDUHV", "P4 Secret")

        // Case E: otpauth:// URI
        let uri = "otpauth://totp/Google:vasilolein54@gmail.com?secret=4DM2M47UQISBDUHV&issuer=Google"
        let p5 = SmartParser.parse(uri)
        assertTrue(p5 != nil, "Parsed otpauth:// URI")
        assertEqual(p5?.issuer, "Google", "P5 Issuer")
        assertEqual(p5?.name, "vasilolein54@gmail.com", "P5 Name")
        assertEqual(p5?.secret, "4DM2M47UQISBDUHV", "P5 Secret")

        // Case F: Multi-line parsing
        let multi = """
        4DM2M47UQISBDUHV vasilolein54@gmail.com
        user2@example.com JBSWY3DPEHPK3PXP
        """
        let multiResults = SmartParser.parseMultiple(multi)
        assertEqual(multiResults.count, 2, "Multi-line parsed 2 entries")
        assertEqual(multiResults[0].secret, "4DM2M47UQISBDUHV", "Multi line item 0 secret")
        assertEqual(multiResults[1].secret, "JBSWY3DPEHPK3PXP", "Multi line item 1 secret")
    }

    // MARK: - 3. Base32 Cleaning Tests
    static func testBase32Decoding() {
        print("📌 Testing Base32 cleaning & decoding...")

        let raw = " 4dm2 - m47u qisb - duhv = "
        let cleaned = SmartParser.cleanSecret(raw)
        assertEqual(cleaned, "4DM2M47UQISBDUHV", "Cleaned secret string")

        let decoded = TOTPGenerator.decodeBase32(cleaned)
        assertTrue(decoded != nil && decoded!.count > 0, "Decoded Base32 binary data")
    }

    // MARK: - 4. AccountStore & Storage Tests
    static func testAccountStoreAndDeduplication() {
        print("📌 Testing AccountStore operations & deduplication...")

        let testDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = AccountStore(directory: testDir)
        store.deleteAllAccounts()
        assertEqual(store.accounts.count, 0, "Store cleared initially")

        // Add 1st account with explicit issuer "GitHub"
        let added1 = store.addAccount(name: "test1@example.com", issuer: "GitHub", secret: "4DM2M47UQISBDUHV")
        assertTrue(added1, "Added 1st account")
        assertEqual(store.accounts.count, 1, "1 account in store")
        assertEqual(store.lastUsedIssuer, "GitHub", "Last used issuer is GitHub")

        // Add 2nd account with missing/empty issuer -> should fallback to lastUsedIssuer ("GitHub")
        let added2 = store.addAccount(name: "test2@example.com", issuer: "", secret: "JBSWY3DPEHPK3PXP")
        assertTrue(added2, "Added 2nd account with empty issuer")
        assertEqual(store.accounts.count, 2, "2 accounts in store")
        assertEqual(store.accounts[1].issuer, "GitHub", "Fallback to last used issuer GitHub")

        // Add duplicate account with same secret -> should deduplicate / update
        let addedDup = store.addAccount(name: "updated_name@example.com", issuer: "GitHub", secret: "4DM2M47UQISBDUHV")
        assertTrue(addedDup, "Handled duplicate secret")
        assertEqual(store.accounts.count, 2, "Store count remains 2 due to deduplication")
        assertEqual(store.accounts[0].name, "updated_name@example.com", "Account updated name")

        // Export vault JSON
        let json = store.exportVault()
        assertTrue(json != nil && json!.contains("4DM2M47UQISBDUHV"), "Exported vault contains secret")

        // Import vault
        let imported = store.importVault(jsonString: json!)
        assertTrue(imported >= 1, "Imported vault successfully")

        // Cleanup
        store.deleteAllAccounts()
        assertEqual(store.accounts.count, 0, "Store cleared finally")
    }
}
