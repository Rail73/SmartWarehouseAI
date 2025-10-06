//
//  OCRBasedPDFParser.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import PDFKit
import Vision
import UIKit

/// Parser for scanned PDF catalogs using Vision OCR
class OCRBasedPDFParser: PDFParserStrategy {
    let name = "OCR-Based Parser"
    private let config: PDFParserConfig

    init(config: PDFParserConfig = .default) {
        self.config = config
    }

    func canParse(_ document: PDFDocument) -> Bool {
        guard config.enableOCR else { return false }

        // Check if PDF has little or no extractable text (likely a scan)
        guard let firstPage = document.page(at: 0) else {
            return false
        }

        let text = firstPage.string ?? ""

        // Heuristic: If text is very short or empty, it's likely a scan
        return text.count < 100
    }

    func parse(_ document: PDFDocument) async throws -> PDFParseResult {
        var parsedItems: [ParsedItem] = []
        var warnings: [String] = []
        var errors: [String] = []

        let pageCount = config.maxPages > 0 ? min(config.maxPages, document.pageCount) : document.pageCount

        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else {
                warnings.append("Page \(pageIndex + 1): Cannot access page")
                continue
            }

            do {
                let pageItems = try await parsePageWithOCR(page, pageNumber: pageIndex + 1)
                parsedItems.append(contentsOf: pageItems)
            } catch {
                errors.append("Page \(pageIndex + 1): OCR failed - \(error.localizedDescription)")
            }
        }

        // Filter by confidence
        let filteredItems = parsedItems.filter { $0.confidence >= config.minimumConfidence }

        if filteredItems.count < parsedItems.count {
            warnings.append("Filtered \(parsedItems.count - filteredItems.count) items due to low confidence")
        }

        return PDFParseResult(
            items: filteredItems,
            totalPages: pageCount,
            parseMethod: name,
            warnings: warnings,
            errors: errors
        )
    }

    // MARK: - OCR Processing

    private func parsePageWithOCR(_ page: PDFPage, pageNumber: Int) async throws -> [ParsedItem] {
        // Convert PDF page to image
        guard let image = renderPageToImage(page) else {
            throw PDFParserError.ocrFailed("Cannot render page to image")
        }

        // Perform OCR
        let recognizedText = try await recognizeText(in: image)

        // Parse recognized text
        return parseRecognizedText(recognizedText, pageNumber: pageNumber)
    }

    private func renderPageToImage(_ page: PDFPage) -> UIImage? {
        let pageBounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0 // Higher resolution for better OCR
        let scaledSize = CGSize(
            width: pageBounds.width * scale,
            height: pageBounds.height * scale
        )

        let renderer = UIGraphicsImageRenderer(size: scaledSize)

        return renderer.image { context in
            UIColor.white.set()
            context.fill(CGRect(origin: .zero, size: scaledSize))

            context.cgContext.translateBy(x: 0, y: scaledSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)

            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }

    private func recognizeText(in image: UIImage) async throws -> [VNRecognizedTextObservation] {
        guard let cgImage = image.cgImage else {
            throw PDFParserError.ocrFailed("Cannot convert image to CGImage")
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en", "ru"] // English and Russian
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try handler.perform([request])

                if let results = request.results {
                    continuation.resume(returning: results)
                } else {
                    continuation.resume(throwing: PDFParserError.ocrFailed("No results from OCR"))
                }
            } catch {
                continuation.resume(throwing: PDFParserError.ocrFailed(error.localizedDescription))
            }
        }
    }

    private func parseRecognizedText(_ observations: [VNRecognizedTextObservation], pageNumber: Int) -> [ParsedItem] {
        var items: [ParsedItem] = []

        // Extract text lines with confidence
        var textLines: [(text: String, confidence: Float)] = []

        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }

            textLines.append((
                text: candidate.string,
                confidence: candidate.confidence
            ))
        }

        // Sort by vertical position (top to bottom)
        let sortedLines = textLines.sorted { lhs, rhs in
            let lhsBounds = observations.first(where: { $0.topCandidates(1).first?.string == lhs.text })?.boundingBox.origin.y ?? 0
            let rhsBounds = observations.first(where: { $0.topCandidates(1).first?.string == rhs.text })?.boundingBox.origin.y ?? 0
            return lhsBounds > rhsBounds // Higher Y = top of page
        }

        // Parse lines into items
        for line in sortedLines {
            let text = line.text.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }

            // Try to extract item information
            if let item = parseLineAsItem(text, confidence: Double(line.confidence), pageNumber: pageNumber) {
                items.append(item)
            }
        }

        return items
    }

    private func parseLineAsItem(_ text: String, confidence: Double, pageNumber: Int) -> ParsedItem? {
        // Skip header-like text
        let skipWords = ["page", "catalog", "price", "list", "inventory", "stock"]
        if skipWords.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
            return nil
        }

        // Extract SKU pattern
        let sku = extractSKU(from: text)

        // If no SKU found and text is too short, skip
        guard sku != nil || text.count > 5 else {
            return nil
        }

        // Use entire text as name if no better structure
        var name = text
        var description: String?

        // Try to split if contains parentheses
        if let range = text.range(of: #"\((.+?)\)"#, options: .regularExpression) {
            description = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            name = text.replacingOccurrences(of: description ?? "", with: "")
                .trimmingCharacters(in: .whitespaces)
        }

        // If we have SKU, remove it from name
        if let skuValue = sku {
            name = name.replacingOccurrences(of: skuValue, with: "")
                .trimmingCharacters(in: .whitespaces)
        }

        guard !name.isEmpty else { return nil }

        return ParsedItem(
            name: name,
            sku: sku,
            description: description,
            confidence: confidence * 0.8, // Reduce confidence for OCR
            pageNumber: pageNumber
        )
    }

    private func extractSKU(from text: String) -> String? {
        // Pattern: Uppercase letters with numbers and dashes
        let patterns = [
            #"[A-Z]{2,}[\-0-9A-Z]+"#,      // BOLT-M6-20
            #"\b[A-Z]\d{3,}\b"#,           // A1234
            #"\b\d{4,}\b"#                  // 123456
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                return String(text[range])
            }
        }

        return nil
    }
}
