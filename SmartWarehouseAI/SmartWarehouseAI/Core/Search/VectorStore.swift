//
//  VectorStore.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import GRDB

/// Vector storage and similarity search using SQLite
/// Stores and retrieves vector embeddings for items
class VectorStore {
    private let dbManager = DatabaseManager.shared
    private let embeddingEngine = EmbeddingEngine()

    // MARK: - Setup

    /// Initialize vector storage table
    func setupVectorTable() async throws {
        guard let db = dbManager.getDatabase() else {
            throw NSError(domain: "VectorStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database not available"])
        }

        try await db.write { db in
            // Create vectors table
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS item_vectors (
                    itemId INTEGER PRIMARY KEY,
                    vector BLOB NOT NULL,
                    dimension INTEGER NOT NULL,
                    updatedAt TEXT NOT NULL,
                    FOREIGN KEY (itemId) REFERENCES items(id) ON DELETE CASCADE
                )
            """)

            // Create index for faster lookups
            try db.execute(sql: """
                CREATE INDEX IF NOT EXISTS idx_item_vectors_updatedAt
                ON item_vectors(updatedAt)
            """)
        }
    }

    // MARK: - Store Vectors

    /// Store or update vector for an item
    func storeVector(itemId: Int64, vector: [Double]) async throws {
        guard let db = dbManager.getDatabase() else { return }
        guard vector.isValid else {
            throw NSError(domain: "VectorStore", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid vector"])
        }

        try await db.write { db in
            let vectorData = vector.toData()
            let now = ISO8601DateFormatter().string(from: Date())

            try db.execute(
                sql: """
                    INSERT INTO item_vectors (itemId, vector, dimension, updatedAt)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(itemId) DO UPDATE SET
                        vector = excluded.vector,
                        dimension = excluded.dimension,
                        updatedAt = excluded.updatedAt
                """,
                arguments: [itemId, vectorData, vector.count, now]
            )
        }
    }

    /// Generate and store vectors for all items
    func indexAllItems() async throws -> Int {
        guard let db = dbManager.getDatabase() else { return 0 }

        let items = try await db.read { db in
            try Item.fetchAll(db)
        }

        var indexed = 0

        for item in items {
            // Create text representation for embedding
            let text = createSearchableText(for: item)

            // Generate embedding
            if let vector = embeddingEngine.embed(text) {
                try await storeVector(itemId: item.id!, vector: vector)
                indexed += 1
            }
        }

        return indexed
    }

    /// Update vector for a single item
    func updateItemVector(_ item: Item) async throws {
        guard let itemId = item.id else { return }

        let text = createSearchableText(for: item)

        if let vector = embeddingEngine.embed(text) {
            try await storeVector(itemId: itemId, vector: vector)
        }
    }

    // MARK: - Search Vectors

    /// Search for similar items using vector similarity
    /// - Parameters:
    ///   - query: Search query text
    ///   - limit: Maximum number of results
    ///   - threshold: Minimum similarity score (0.0 - 1.0)
    /// - Returns: Array of items with similarity scores
    func searchSimilar(query: String, limit: Int = 20, threshold: Double = 0.5) async throws -> [SearchResult] {
        guard let db = dbManager.getDatabase() else { return [] }

        // Generate query vector
        guard let queryVector = embeddingEngine.embed(query) else {
            return []
        }

        // Fetch all vectors
        let vectors = try await db.read { db in
            try Row.fetchAll(db, sql: "SELECT itemId, vector FROM item_vectors")
        }

        // Calculate similarities
        var similarities: [(itemId: Int64, score: Double)] = []

        for row in vectors {
            let itemId: Int64 = row["itemId"]
            let vectorData: Data = row["vector"]

            guard let vector = [Double].fromData(vectorData) else { continue }

            let score = embeddingEngine.cosineSimilarity(queryVector, vector)

            if score >= threshold {
                similarities.append((itemId: itemId, score: score))
            }
        }

        // Sort by score descending
        similarities.sort { $0.score > $1.score }

        // Limit results
        let topResults = Array(similarities.prefix(limit))

        // Fetch corresponding items
        guard !topResults.isEmpty else { return [] }

        let itemIds = topResults.map { $0.itemId }

        let items = try await db.read { db in
            try Item.filter(itemIds.contains(Column("id"))).fetchAll(db)
        }

        // Create SearchResults
        var results: [SearchResult] = []
        let itemsDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id!, $0) })

        for (itemId, score) in topResults {
            guard let item = itemsDict[itemId] else { continue }

            results.append(SearchResult(
                item: item,
                score: score,
                matchType: .vector,
                nameSnippet: nil,
                descriptionSnippet: nil
            ))
        }

        return results
    }

    /// Find items similar to a given item
    func findSimilarItems(to itemId: Int64, limit: Int = 10) async throws -> [SearchResult] {
        guard let db = dbManager.getDatabase() else { return [] }

        // Get vector for target item
        guard let targetVectorData = try await db.read({ db in
            try Data.fetchOne(db, sql: "SELECT vector FROM item_vectors WHERE itemId = ?", arguments: [itemId])
        }), let targetVector = [Double].fromData(targetVectorData) else {
            return []
        }

        // Fetch all other vectors
        let vectors = try await db.read { db in
            try Row.fetchAll(db, sql: "SELECT itemId, vector FROM item_vectors WHERE itemId != ?", arguments: [itemId])
        }

        // Calculate similarities
        var similarities: [(itemId: Int64, score: Double)] = []

        for row in vectors {
            let otherId: Int64 = row["itemId"]
            let vectorData: Data = row["vector"]

            guard let vector = [Double].fromData(vectorData) else { continue }

            let score = embeddingEngine.cosineSimilarity(targetVector, vector)
            similarities.append((itemId: otherId, score: score))
        }

        // Get top results
        let topResults = Array(similarities.sorted { $0.score > $1.score }.prefix(limit))

        guard !topResults.isEmpty else { return [] }

        let itemIds = topResults.map { $0.itemId }

        let items = try await db.read { db in
            try Item.filter(itemIds.contains(Column("id"))).fetchAll(db)
        }

        var results: [SearchResult] = []
        let itemsDict = Dictionary(uniqueKeysWithValues: items.map { ($0.id!, $0) })

        for (otherId, score) in topResults {
            guard let item = itemsDict[otherId] else { continue }

            results.append(SearchResult(
                item: item,
                score: score,
                matchType: .vector,
                nameSnippet: nil,
                descriptionSnippet: nil
            ))
        }

        return results
    }

    // MARK: - Maintenance

    /// Get statistics about vector storage
    func getStats() async throws -> VectorStats {
        guard let db = dbManager.getDatabase() else {
            return VectorStats(totalVectors: 0, totalItems: 0, coverage: 0.0, avgDimension: 0)
        }

        return try await db.read { db in
            let totalVectors = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM item_vectors") ?? 0
            let totalItems = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM items") ?? 0
            let avgDimension = try Int.fetchOne(db, sql: "SELECT AVG(dimension) FROM item_vectors") ?? 0

            let coverage = totalItems > 0 ? Double(totalVectors) / Double(totalItems) : 0.0

            return VectorStats(
                totalVectors: totalVectors,
                totalItems: totalItems,
                coverage: coverage,
                avgDimension: avgDimension
            )
        }
    }

    /// Delete vector for an item
    func deleteVector(itemId: Int64) async throws {
        guard let db = dbManager.getDatabase() else { return }

        try await db.write { db in
            try db.execute(sql: "DELETE FROM item_vectors WHERE itemId = ?", arguments: [itemId])
        }
    }

    /// Clear all vectors
    func clearAllVectors() async throws {
        guard let db = dbManager.getDatabase() else { return }

        try await db.write { db in
            try db.execute(sql: "DELETE FROM item_vectors")
        }
    }

    // MARK: - Helpers

    /// Create searchable text representation of item
    private func createSearchableText(for item: Item) -> String {
        var parts: [String] = []

        // Name is most important (weight 3x)
        parts.append(item.name)
        parts.append(item.name)
        parts.append(item.name)

        // SKU (weight 2x)
        parts.append(item.sku)
        parts.append(item.sku)

        // Category (weight 2x)
        if let category = item.category {
            parts.append(category)
            parts.append(category)
        }

        // Description (weight 1x)
        if let description = item.itemDescription {
            parts.append(description)
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Vector Stats

struct VectorStats {
    let totalVectors: Int
    let totalItems: Int
    let coverage: Double // 0.0 - 1.0
    let avgDimension: Int
}
