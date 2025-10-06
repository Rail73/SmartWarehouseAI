//
//  PDFParserTypes.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import PDFKit

// MARK: - Parsed Item Result

/// Result of parsing a single item from PDF
struct ParsedItem {
    var name: String
    var sku: String?
    var category: String?
    var description: String?
    var barcode: String?

    /// Confidence level of parsing (0.0 - 1.0)
    var confidence: Double = 1.0

    /// Source page number
    var pageNumber: Int?

    /// Convert to Item model
    func toItem() -> Item {
        Item(
            name: name,
            sku: sku ?? "",
            itemDescription: description,
            category: category,
            barcode: barcode
        )
    }
}

// MARK: - Parser Result

/// Overall result of PDF parsing
struct PDFParseResult {
    let items: [ParsedItem]
    let totalPages: Int
    let parseMethod: String
    let warnings: [String]
    let errors: [String]

    var successRate: Double {
        guard totalPages > 0 else { return 0 }
        return Double(items.count) / Double(totalPages)
    }

    var hasErrors: Bool {
        !errors.isEmpty
    }

    var hasWarnings: Bool {
        !warnings.isEmpty
    }
}

// MARK: - Parser Strategy Protocol

protocol PDFParserStrategy {
    /// Name of the parser strategy
    var name: String { get }

    /// Checks if this parser can handle the PDF
    func canParse(_ document: PDFDocument) -> Bool

    /// Parses the PDF document
    func parse(_ document: PDFDocument) async throws -> PDFParseResult
}

// MARK: - Parser Errors

enum PDFParserError: LocalizedError {
    case cannotOpenFile
    case emptyDocument
    case noSuitableParser
    case parsingFailed(String)
    case invalidFormat(String)
    case ocrFailed(String)

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile:
            return "Cannot open PDF file"
        case .emptyDocument:
            return "PDF document is empty"
        case .noSuitableParser:
            return "No suitable parser found for this PDF format"
        case .parsingFailed(let reason):
            return "Parsing failed: \(reason)"
        case .invalidFormat(let detail):
            return "Invalid PDF format: \(detail)"
        case .ocrFailed(let reason):
            return "OCR recognition failed: \(reason)"
        }
    }
}

// MARK: - Parser Configuration

struct PDFParserConfig {
    /// Minimum confidence threshold (0.0 - 1.0)
    var minimumConfidence: Double = 0.5

    /// Enable OCR for scanned PDFs
    var enableOCR: Bool = true

    /// Maximum pages to process (0 = unlimited)
    var maxPages: Int = 0

    /// Categories to auto-detect
    var autoCategories: [String] = []

    static let `default` = PDFParserConfig()
}
