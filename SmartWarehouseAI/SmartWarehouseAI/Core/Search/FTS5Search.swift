//
//  FTS5Search.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import GRDB

/// FTS5-based full-text search service
/// Provides fast, ranked text search across items
class FTS5Search {
    private let dbManager = DatabaseManager.shared

    // MARK: - Setup

    /// Initialize FTS5 virtual table for items
    func setupFTS5() async throws {
        guard let db = dbManager.getDatabase() else {
            throw NSError(domain: "FTS5Search", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not available"])
        }

        try await db.write { db in
            // Create FTS5 virtual table if not exists
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS items_fts USING fts5(
                    name,
                    sku,
                    itemDescription,
                    category,
                    content='items',
                    content_rowid='id',
                    tokenize='porter unicode61 remove_diacritics 2'
                )
            """)

            // Create triggers to keep FTS5 in sync with items table

            // INSERT trigger
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS items_fts_insert AFTER INSERT ON items BEGIN
                    INSERT INTO items_fts(rowid, name, sku, itemDescription, category)
                    VALUES (new.id, new.name, new.sku, new.itemDescription, new.category);
                END
            """)

            // UPDATE trigger
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS items_fts_update AFTER UPDATE ON items BEGIN
                    UPDATE items_fts SET
                        name = new.name,
                        sku = new.sku,
                        itemDescription = new.itemDescription,
                        category = new.category
                    WHERE rowid = new.id;
                END
            """)

            // DELETE trigger
            try db.execute(sql: """
                CREATE TRIGGER IF NOT EXISTS items_fts_delete AFTER DELETE ON items BEGIN
                    DELETE FROM items_fts WHERE rowid = old.id;
                END
            """)

            // Populate FTS5 table with existing data
            try db.execute(sql: """
                INSERT OR REPLACE INTO items_fts(rowid, name, sku, itemDescription, category)
                SELECT id, name, sku, itemDescription, category FROM items
            """)
        }
    }

    // MARK: - Search

    /// Search items using FTS5 with ranking
    /// - Parameters:
    ///   - query: Search query string
    ///   - limit: Maximum number of results (default: 20)
    /// - Returns: Array of SearchResult with relevance scores
    func search(query: String, limit: Int = 20) async throws -> [SearchResult] {
        guard let db = dbManager.getDatabase() else { return [] }
        guard !query.isEmpty else { return [] }

        // Escape and prepare FTS5 query
        let fts5Query = prepareFTS5Query(query)

        return try await db.read { db in
            let sql = """
                SELECT
                    items.id,
                    items.name,
                    items.sku,
                    items.itemDescription,
                    items.category,
                    items.barcode,
                    items.createdAt,
                    items.updatedAt,
                    bm25(items_fts) AS rank,
                    snippet(items_fts, 0, '<b>', '</b>', '...', 32) AS nameSnippet,
                    snippet(items_fts, 2, '<b>', '</b>', '...', 64) AS descSnippet
                FROM items_fts
                JOIN items ON items.id = items_fts.rowid
                WHERE items_fts MATCH ?
                ORDER BY rank
                LIMIT ?
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [fts5Query, limit])

            return rows.map { row in
                let item = Item(
                    id: row["id"],
                    name: row["name"],
                    sku: row["sku"],
                    itemDescription: row["itemDescription"],
                    category: row["category"],
                    barcode: row["barcode"],
                    createdAt: row["createdAt"],
                    updatedAt: row["updatedAt"]
                )

                // BM25 returns negative scores (lower is better)
                // Convert to 0-1 scale where 1 is best match
                let bm25Score: Double = row["rank"]
                let normalizedScore = max(0, min(1, 1.0 / (1.0 - bm25Score / 10.0)))

                return SearchResult(
                    item: item,
                    score: normalizedScore,
                    matchType: .fullText,
                    nameSnippet: row["nameSnippet"],
                    descriptionSnippet: row["descSnippet"]
                )
            }
        }
    }

    /// Search by category with ranking
    func searchByCategory(_ category: String, limit: Int = 20) async throws -> [SearchResult] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            let items = try Item
                .filter(Column("category") == category)
                .order(Column("name").asc)
                .limit(limit)
                .fetchAll(db)

            return items.map { item in
                SearchResult(
                    item: item,
                    score: 1.0,
                    matchType: .category,
                    nameSnippet: nil,
                    descriptionSnippet: nil
                )
            }
        }
    }

    /// Get search suggestions based on partial input
    func suggestions(for prefix: String, limit: Int = 10) async throws -> [String] {
        guard let db = dbManager.getDatabase() else { return [] }
        guard prefix.count >= 2 else { return [] }

        return try await db.read { db in
            let sql = """
                SELECT DISTINCT name
                FROM items
                WHERE name LIKE ?
                ORDER BY name
                LIMIT ?
            """

            let pattern = "\(prefix)%"
            return try String.fetchAll(db, sql: sql, arguments: [pattern, limit])
        }
    }

    // MARK: - Helpers

    /// Prepare FTS5 query by escaping special characters and adding wildcards
    private func prepareFTS5Query(_ query: String) -> String {
        // Remove special FTS5 characters
        let cleaned = query.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: ":", with: " ")

        // Split into words and add prefix matching
        let words = cleaned.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        if words.isEmpty { return "" }

        // Support both exact phrase and individual word matching
        if words.count == 1 {
            return "\(words[0])*"
        } else {
            // Multi-word: try phrase match first, then individual words
            let phraseMatch = "\"\(words.joined(separator: " "))\""
            let individualWords = words.map { "\($0)*" }.joined(separator: " OR ")
            return "\(phraseMatch) OR \(individualWords)"
        }
    }
}

// MARK: - Search Result

/// Result from FTS5 search with relevance scoring
struct SearchResult: Identifiable {
    var id: Int64 { item.id ?? 0 }

    let item: Item
    let score: Double // 0.0 - 1.0, higher is better
    let matchType: MatchType
    let nameSnippet: String? // HTML snippet with <b> tags
    let descriptionSnippet: String?

    enum MatchType: String {
        case fullText = "Full-text"
        case vector = "Semantic"
        case hybrid = "Hybrid"
        case category = "Category"
        case exact = "Exact"
    }
}
