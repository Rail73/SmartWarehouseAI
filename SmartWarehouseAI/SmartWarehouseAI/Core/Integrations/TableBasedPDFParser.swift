//
//  TableBasedPDFParser.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import PDFKit

/// Parser for structured PDF catalogs with tables
class TableBasedPDFParser: PDFParserStrategy {
    let name = "Table-Based Parser"
    private let config: PDFParserConfig

    init(config: PDFParserConfig = .default) {
        self.config = config
    }

    func canParse(_ document: PDFDocument) -> Bool {
        // Check if PDF has extractable text
        guard let firstPage = document.page(at: 0),
              let text = firstPage.string else {
            return false
        }

        // Heuristic: Check if text contains table-like patterns
        let hasColumns = text.contains("\t") || text.contains("  ")
        let hasNumbers = text.range(of: "\\d+", options: .regularExpression) != nil

        return !text.isEmpty && (hasColumns || hasNumbers)
    }

    func parse(_ document: PDFDocument) async throws -> PDFParseResult {
        var parsedItems: [ParsedItem] = []
        var warnings: [String] = []
        var errors: [String] = []

        let pageCount = config.maxPages > 0 ? min(config.maxPages, document.pageCount) : document.pageCount

        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex),
                  let pageText = page.string else {
                warnings.append("Page \(pageIndex + 1): Cannot extract text")
                continue
            }

            let pageItems = parsePageText(pageText, pageNumber: pageIndex + 1)
            parsedItems.append(contentsOf: pageItems)
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

    // MARK: - Private Parsing Logic

    private func parsePageText(_ text: String, pageNumber: Int) -> [ParsedItem] {
        var items: [ParsedItem] = []

        // Split into lines
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for line in lines {
            // Try different parsing strategies
            if let item = parseTabDelimited(line, pageNumber: pageNumber) {
                items.append(item)
            } else if let item = parseSpaceDelimited(line, pageNumber: pageNumber) {
                items.append(item)
            } else if let item = parseKeyValue(line, pageNumber: pageNumber) {
                items.append(item)
            }
        }

        return items
    }

    /// Parse tab-delimited format: "SKU\tName\tDescription"
    private func parseTabDelimited(_ line: String, pageNumber: Int) -> ParsedItem? {
        let components = line.components(separatedBy: "\t")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard components.count >= 2 else { return nil }

        // Heuristic: First column is SKU, second is name
        let sku = components[0]
        let name = components[1]
        let description = components.count > 2 ? components[2...].joined(separator: " ") : nil

        return ParsedItem(
            name: name,
            sku: sku,
            description: description,
            confidence: 0.9,
            pageNumber: pageNumber
        )
    }

    /// Parse space-delimited format with patterns
    private func parseSpaceDelimited(_ line: String, pageNumber: Int) -> ParsedItem? {
        // Pattern: "CODE-123 Item Name (optional description)"
        let pattern = #"^([A-Z0-9\-]+)\s+(.+?)(?:\s*\((.+?)\))?$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        var sku: String?
        var name: String?
        var description: String?

        if let skuRange = Range(match.range(at: 1), in: line) {
            sku = String(line[skuRange])
        }

        if let nameRange = Range(match.range(at: 2), in: line) {
            name = String(line[nameRange]).trimmingCharacters(in: .whitespaces)
        }

        if match.numberOfRanges > 3, let descRange = Range(match.range(at: 3), in: line) {
            description = String(line[descRange])
        }

        guard let finalName = name, !finalName.isEmpty else { return nil }

        return ParsedItem(
            name: finalName,
            sku: sku,
            description: description,
            confidence: 0.8,
            pageNumber: pageNumber
        )
    }

    /// Parse key-value format: "Name: Value"
    private func parseKeyValue(_ line: String, pageNumber: Int) -> ParsedItem? {
        // Simple key-value extraction
        guard line.contains(":") else { return nil }

        let parts = line.components(separatedBy: ":")
        guard parts.count == 2 else { return nil }

        let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
        let value = parts[1].trimmingCharacters(in: .whitespaces)

        // Only parse if key looks like "name", "item", "product"
        let validKeys = ["name", "item", "product", "part"]
        guard validKeys.contains(where: { key.contains($0) }) else { return nil }

        return ParsedItem(
            name: value,
            sku: nil,
            description: nil,
            confidence: 0.6,
            pageNumber: pageNumber
        )
    }

    // MARK: - Helper Methods

    private func extractSKU(from text: String) -> String? {
        // Pattern: Uppercase letters with numbers and dashes
        let pattern = #"[A-Z]{2,}[\-0-9A-Z]+"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }

        return String(text[range])
    }

    private func detectCategory(from text: String) -> String? {
        let categories = config.autoCategories

        for category in categories {
            if text.localizedCaseInsensitiveContains(category) {
                return category
            }
        }

        return nil
    }
}
