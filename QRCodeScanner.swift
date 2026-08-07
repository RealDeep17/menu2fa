import Foundation
import CoreGraphics
import Vision
import AppKit

struct QRCodeScanner {
    /// Scans a CGImage for 2FA QR code
    static func scanCGImage(_ cgImage: CGImage, completion: @escaping (Parsed2FA?, String?) -> Void) {
        let request = VNDetectBarcodesRequest { request, error in
            guard let results = request.results as? [VNBarcodeObservation], error == nil else {
                DispatchQueue.main.async { completion(nil, "No QR code detected on screen. Make sure the QR code is fully visible.") }
                return
            }

            for result in results {
                if result.symbology == .qr, let payload = result.payloadStringValue {
                    if let parsed = SmartParser.parse(payload) {
                        DispatchQueue.main.async { completion(parsed, nil) }
                        return
                    } else {
                        DispatchQueue.main.async { completion(nil, "Scanned QR code payload is not a valid 2FA secret or URI.") }
                        return
                    }
                }
            }
            DispatchQueue.main.async { completion(nil, "No 2FA QR code found on screen.") }
        }
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    /// Scans screen or clipboard image for 2FA QR code
    static func scanScreenOrClipboard(completion: @escaping (Parsed2FA?, String?) -> Void) {
        // 1. Try scanning clipboard image first (No permissions needed)
        if let pasteboardImage = NSImage(pasteboard: NSPasteboard.general),
           let cgImage = pasteboardImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            scanCGImage(cgImage) { parsed, error in
                if let parsed = parsed {
                    completion(parsed, nil)
                } else {
                    // Fallback to screen capture
                    scanDisplayScreen(completion: completion)
                }
            }
            return
        }

        // 2. Scan display screen
        scanDisplayScreen(completion: completion)
    }

    private static func scanDisplayScreen(completion: @escaping (Parsed2FA?, String?) -> Void) {
        // Attempt display capture directly first (bypasses macOS preflight permission delay)
        if let cgImage = CGDisplayCreateImage(CGMainDisplayID()) ?? CGWindowListCreateImage(.null, .optionOnScreenOnly, kCGNullWindowID, .bestResolution),
           cgImage.width > 50, cgImage.height > 50 {
            scanCGImage(cgImage, completion: completion)
            return
        }

        // If direct display capture returned empty or failed, request Screen Recording permission
        if #available(macOS 10.15, *) {
            if !CGPreflightScreenCaptureAccess() {
                _ = CGRequestScreenCaptureAccess()
                completion(nil, "Screen Recording permission is required to scan your display.\n\nPlease grant Screen Recording permission to Menu2FA in System Settings -> Privacy & Security -> Screen Recording.")
                return
            }
        }

        completion(nil, "Failed to capture screen image. Please restart Menu2FA after enabling Screen Recording permission.")
    }
}
