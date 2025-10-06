//
//  PDFImportService.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import PDFKit

// MARK: - PDF Parser Factory

class PDFParserFactory {
    static func selectParser(for document: PDFDocument, config: PDFParserConfig = .default) -> PDFParserStrategy {
        let parsers: [PDFParserStrategy] = [
            TableBasedPDFParser(config: config),
            OCRBasedPDFParser(config: config)
        ]

        // Try each parser in order of preference
        for parser in parsers {
            if parser.canParse(document) {
                print("📄 Selected parser: \(parser.name)")
                return parser
            }
        }

        // Fallback to table-based parser
        print("⚠️ No suitable parser found, using Table-Based as fallback")
        return TableBasedPDFParser(config: config)
    }
}

// MARK: - PDF Import Service

class PDFImportService {
    private let itemService = ItemService()
    private let config: PDFParserConfig

    init(config: PDFParserConfig = .default) {
        self.config = config
    }

    // MARK: - Import from URL

    func importCatalog(from url: URL) async throws -> ImportResult {
        print("📥 Starting PDF import from: \(url.lastPathComponent)")

        // Load PDF document
        guard let document = PDFDocument(url: url) else {
            throw PDFParserError.cannotOpenFile
        }

        guard document.pageCount > 0 else {
            throw PDFParserError.emptyDocument
        }

        print("📄 PDF loaded: \(document.pageCount) pages")

        // Select appropriate parser
        let parser = PDFParserFactory.selectParser(for: document, config: config)

        // Parse document
        let parseResult = try await parser.parse(document)

        print("✅ Parsing complete: \(parseResult.items.count) items found")

        // Create import result
        let result = ImportResult(
            sourceFile: url.lastPathComponent,
            parseResult: parseResult,
            importedItems: [],
            skippedItems: []
        )

        return result
    }

    // MARK: - Save Items to Database

    func saveItems(_ parsedItems: [ParsedItem]) async throws -> SaveResult {
        var imported: [Item] = []
        var skipped: [(ParsedItem, String)] = []

        for parsedItem in parsedItems {
            do {
                // Check if item with same SKU already exists
                if let sku = parsedItem.sku, !sku.isEmpty {
                    if let existing = try await itemService.fetchBySKU(sku) {
                        skipped.append((parsedItem, "SKU '\(sku)' already exists (ID: \(existing.id ?? 0))"))
                        continue
                    }
                }

                // Create new item
                let item = parsedItem.toItem()
                let created = try await itemService.create(item)
                imported.append(created)

                print("  ✅ Imported: \(created.name) (SKU: \(created.sku))")
            } catch {
                skipped.append((parsedItem, error.localizedDescription))
                print("  ❌ Skipped: \(parsedItem.name) - \(error.localizedDescription)")
            }
        }

        return SaveResult(
            imported: imported,
            skipped: skipped
        )
    }

    // MARK: - Full Import Workflow

    func importAndSave(from url: URL) async throws -> CompleteImportResult {
        // Step 1: Parse PDF
        let importResult = try await importCatalog(from: url)

        // Step 2: Save to database
        let saveResult = try await saveItems(importResult.parseResult.items)

        return CompleteImportResult(
            sourceFile: importResult.sourceFile,
            parseResult: importResult.parseResult,
            saveResult: saveResult
        )
    }
}

// MARK: - Result Types

struct ImportResult {
    let sourceFile: String
    let parseResult: PDFParseResult
    let importedItems: [Item]
    let skippedItems: [(ParsedItem, String)]
}

struct SaveResult {
    let imported: [Item]
    let skipped: [(ParsedItem, String)]

    var successCount: Int { imported.count }
    var skipCount: Int { skipped.count }
    var totalCount: Int { successCount + skipCount }

    var successRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(successCount) / Double(totalCount)
    }
}

struct CompleteImportResult {
    let sourceFile: String
    let parseResult: PDFParseResult
    let saveResult: SaveResult

    var summary: String {
        """
        📄 Import Summary

        Source: \(sourceFile)
        Parser: \(parseResult.parseMethod)
        Pages: \(parseResult.totalPages)

        Parsed: \(parseResult.items.count) items
        Imported: \(saveResult.successCount) items
        Skipped: \(saveResult.skipCount) items
        Success Rate: \(String(format: "%.1f%%", saveResult.successRate * 100))

        Warnings: \(parseResult.warnings.count)
        Errors: \(parseResult.errors.count)
        """
    }
}
