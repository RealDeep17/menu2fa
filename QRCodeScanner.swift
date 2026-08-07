import Foundation
import CoreGraphics
import Vision
import AppKit

struct QRCodeScanner {
    /// Scans a CGImage for 2FA QR code or visible Base32 secret text
    static func scanCGImage(_ cgImage: CGImage, completion: @escaping (Parsed2FA?, String?) -> Void) {
        // 1. Try Barcode Recognition (QR Code)
        let barcodeRequest = VNDetectBarcodesRequest { request, error in
            if let results = request.results as? [VNBarcodeObservation], error == nil {
                for result in results {
                    if result.symbology == .qr, let payload = result.payloadStringValue {
                        if let parsed = SmartParser.parse(payload) {
                            DispatchQueue.main.async { completion(parsed, nil) }
                            return
                        }
                    }
                }
            }

            // 2. Fallback: OCR Text Recognition for visible secret keys (e.g. 3F2KHCTHLJ5T6VUR)
            let ocrRequest = VNRecognizeTextRequest { textReq, textErr in
                if let textResults = textReq.results as? [VNRecognizedTextObservation] {
                    for obs in textResults {
                        guard let topCandidate = obs.topCandidates(1).first else { continue }
                        let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let parsed = SmartParser.parse(text), SmartParser.isBase32Secret(parsed.secret) {
                            DispatchQueue.main.async { completion(parsed, nil) }
                            return
                        }
                    }
                }
                DispatchQueue.main.async { completion(nil, "No 2FA QR code or secret key found on screen.") }
            }
            ocrRequest.recognitionLevel = .accurate

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([ocrRequest])
        }
        barcodeRequest.symbologies = [.qr]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([barcodeRequest])
        }
    }

    /// Scans screen across displays or clipboard image for 2FA QR code / key
    static func scanScreenOrClipboard(completion: @escaping (Parsed2FA?, String?) -> Void) {
        // 1. Try scanning clipboard image first (No permissions needed)
        if let pasteboardImage = NSImage(pasteboard: NSPasteboard.general),
           let cgImage = pasteboardImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            scanCGImage(cgImage) { parsed, error in
                if let parsed = parsed {
                    completion(parsed, nil)
                } else {
                    scanDisplayScreen(completion: completion)
                }
            }
            return
        }

        // 2. Scan display screen
        scanDisplayScreen(completion: completion)
    }

    private static func scanDisplayScreen(completion: @escaping (Parsed2FA?, String?) -> Void) {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        
        if displayCount > 0 {
            var activeDisplays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
            CGGetActiveDisplayList(displayCount, &activeDisplays, &displayCount)

            for displayID in activeDisplays {
                if let cgImage = CGDisplayCreateImage(displayID), cgImage.width > 50, cgImage.height > 50 {
                    var found: Parsed2FA? = nil
                    let group = DispatchGroup()
                    group.enter()

                    scanCGImage(cgImage) { parsed, _ in
                        if let parsed = parsed {
                            found = parsed
                        }
                        group.leave()
                    }

                    group.wait()
                    if let result = found {
                        completion(result, nil)
                        return
                    }
                }
            }
        }

        // Fallback to window list image
        if let cgImage = CGWindowListCreateImage(.null, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) {
            scanCGImage(cgImage, completion: completion)
            return
        }

        completion(nil, "Failed to capture screen image. Ensure Screen Recording permission is enabled in System Settings.")
    }
}
