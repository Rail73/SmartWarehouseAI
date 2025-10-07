//
//  QRManager.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import Foundation
import UIKit
import CryptoKit
import CoreImage.CIFilterBuiltins

/// QR Code generation and validation with HMAC signatures
class QRManager {
    static let shared = QRManager()

    private let keychain = KeychainHelper.shared
    private let hmacKeyName = "com.smartwarehouse.ai.qr.hmackey"

    private init() {
        // Generate HMAC key if it doesn't exist
        ensureHMACKey()
    }

    // MARK: - HMAC Key Management

    private func ensureHMACKey() {
        if keychain.load(key: hmacKeyName) == nil {
            // Generate new 256-bit random key
            let key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            _ = keychain.save(key: hmacKeyName, data: keyData)
        }
    }

    private func getHMACKey() -> SymmetricKey? {
        guard let keyData = keychain.load(key: hmacKeyName) else {
            return nil
        }
        return SymmetricKey(data: keyData)
    }

    // MARK: - HMAC Signing

    private func sign(payload: String) -> String? {
        guard let key = getHMACKey() else { return nil }
        guard let payloadData = payload.data(using: .utf8) else { return nil }

        let signature = HMAC<SHA256>.authenticationCode(for: payloadData, using: key)
        return Data(signature).base64EncodedString()
    }

    private func verify(payload: String, signature: String) -> Bool {
        guard let key = getHMACKey() else { return false }
        guard let payloadData = payload.data(using: .utf8) else { return false }
        guard let signatureData = Data(base64Encoded: signature) else { return false }

        let expectedSignature = HMAC<SHA256>.authenticationCode(for: payloadData, using: key)
        return Data(expectedSignature) == signatureData
    }

    // MARK: - QR Code Generation

    enum QRCodeType {
        case item(Int64)
        case kit(Int64)
        case warehouse(Int64)

        var urlString: String {
            switch self {
            case .item(let id):
                return "swai://item/\(id)"
            case .kit(let id):
                return "swai://kit/\(id)"
            case .warehouse(let id):
                return "swai://warehouse/\(id)"
            }
        }

        var payload: String {
            switch self {
            case .item(let id):
                return "item:\(id)"
            case .kit(let id):
                return "kit:\(id)"
            case .warehouse(let id):
                return "warehouse:\(id)"
            }
        }
    }

    /// Generate QR code image for an item or kit
    func generateQRCode(for type: QRCodeType, size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        guard let signature = sign(payload: type.payload) else {
            print("Failed to sign QR code payload")
            return nil
        }

        // Encode signature in URL-safe base64
        let urlSafeSignature = signature
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let qrString = "\(type.urlString)?sig=\(urlSafeSignature)"

        return generateQRImage(from: qrString, size: size)
    }

    private func generateQRImage(from string: String, size: CGSize) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()

        guard let data = string.data(using: .utf8) else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let ciImage = filter.outputImage else { return nil }

        // Scale to desired size
        let scaleX = size.width / ciImage.extent.width
        let scaleY = size.height / ciImage.extent.height
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - QR Code Validation

    struct QRCodeData {
        let type: QRCodeType
        let isValid: Bool
    }

    /// Parse and validate QR code string
    func parseQRCode(_ qrString: String) -> QRCodeData? {
        // Parse URL: swai://item/123?sig=abc or swai://kit/456?sig=xyz
        guard let url = URL(string: qrString),
              url.scheme == "swai",
              let host = url.host else {
            return nil
        }

        // Extract type and ID
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count == 1,
              let id = Int64(pathComponents[0]) else {
            return nil
        }

        let type: QRCodeType
        switch host {
        case "item":
            type = .item(id)
        case "kit":
            type = .kit(id)
        case "warehouse":
            type = .warehouse(id)
        default:
            return nil
        }

        // Extract and verify signature
        guard let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let signatureParam = queryItems.first(where: { $0.name == "sig" })?.value else {
            return QRCodeData(type: type, isValid: false)
        }

        // Convert URL-safe base64 back to standard base64
        var signature = signatureParam
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddingLength = (4 - signature.count % 4) % 4
        signature += String(repeating: "=", count: paddingLength)

        let isValid = verify(payload: type.payload, signature: signature)

        return QRCodeData(type: type, isValid: isValid)
    }
}
