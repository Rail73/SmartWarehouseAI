//
//  SearchService.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation

/// Unified search service combining FTS5 and vector search
/// Provides hybrid search with automatic ranking
class SearchService {
    private let fts5Search = FTS5Search()
    private let vectorStore = VectorStore()
    private let itemService = ItemService()

    // MARK: - Setup

    /// Initialize search infrastructure (FTS5 + Vectors)
    func initialize() async throws {
        // Setup FTS5
        try await fts5Search.setupFTS5()

        // Setup vector store
        try await vectorStore.setupVectorTable()

        print("✅ Search infrastructure initialized")
    }

    /// Index all items for search (FTS5 + Vectors)
    func indexAll() async throws -> IndexStats {
        let startTime = Date()

        // FTS5 is auto-indexed via triggers
        // Only need to index vectors
        let vectorCount = try await vectorStore.indexAllItems()

        let duration = Date().timeIntervalSince(startTime)

        print("✅ Indexed \(vectorCount) items in \(String(format: "%.2f", duration))s")

        return IndexStats(
            itemsIndexed: vectorCount,
            duration: duration,
            fts5Enabled: true,
            vectorsEnabled: true
        )
    }

    /// Update index for a single item
    func updateIndex(for item: Item) async throws {
        // FTS5 is auto-updated via triggers
        // Update vector
        try await vectorStore.updateItemVector(item)
    }

    // MARK: - Hybrid Search

    /// Hybrid search combining FTS5 and vector search
    /// - Parameters:
    ///   - query: Search query
    ///   - mode: Search mode (auto, fullText, semantic, hybrid)
    ///   - limit: Maximum results
    /// - Returns: Ranked search results
    func search(query: String, mode: SearchMode = .auto, limit: Int = 20) async throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        let effectiveMode = mode == .auto ? determineSearchMode(query) : mode

        switch effectiveMode {
        case .fullText:
            return try await fts5Search.search(query: query, limit: limit)

        case .semantic:
            return try await vectorStore.searchSimilar(query: query, limit: limit, threshold: 0.4)

        case .hybrid:
            return try await hybridSearch(query: query, limit: limit)

        case .auto:
            fatalError("Auto mode should be resolved before reaching this point")
        }
    }

    /// Hybrid search with result fusion
    private func hybridSearch(query: String, limit: Int) async throws -> [SearchResult] {
        // Run both searches in parallel
        async let fts5Results = fts5Search.search(query: query, limit: limit * 2)
        async let vectorResults = vectorStore.searchSimilar(query: query, limit: limit * 2, threshold: 0.3)

        let (ftsRes, vecRes) = try await (fts5Results, vectorResults)

        // Merge and re-rank results using Reciprocal Rank Fusion (RRF)
        let fusedResults = fuseResults(fts5: ftsRes, vector: vecRes, k: 60)

        // Return top results
        return Array(fusedResults.prefix(limit))
    }

    /// Reciprocal Rank Fusion (RRF) for combining ranked lists
    /// RRF(d) = Σ 1 / (k + rank(d))
    private func fuseResults(fts5: [SearchResult], vector: [SearchResult], k: Int = 60) -> [SearchResult] {
        var scoreMap: [Int64: (item: Item, score: Double)] = [:]

        // Add FTS5 scores
        for (rank, result) in fts5.enumerated() {
            guard let itemId = result.item.id else { continue }

            let rrfScore = 1.0 / Double(k + rank + 1)

            if let existing = scoreMap[itemId] {
                scoreMap[itemId] = (item: result.item, score: existing.score + rrfScore)
            } else {
                scoreMap[itemId] = (item: result.item, score: rrfScore)
            }
        }

        // Add vector scores
        for (rank, result) in vector.enumerated() {
            guard let itemId = result.item.id else { continue }

            let rrfScore = 1.0 / Double(k + rank + 1)

            if let existing = scoreMap[itemId] {
                scoreMap[itemId] = (item: result.item, score: existing.score + rrfScore)
            } else {
                scoreMap[itemId] = (item: result.item, score: rrfScore)
            }
        }

        // Convert to SearchResult and sort
        let results = scoreMap.map { itemId, data in
            SearchResult(
                item: data.item,
                score: data.score,
                matchType: .hybrid,
                nameSnippet: nil,
                descriptionSnippet: nil
            )
        }

        return results.sorted { $0.score > $1.score }
    }

    // MARK: - Specialized Searches

    /// Search by exact SKU
    func searchBySKU(_ sku: String) async throws -> Item? {
        return try await itemService.fetchBySKU(sku)
    }

    /// Search by category
    func searchByCategory(_ category: String, limit: Int = 20) async throws -> [SearchResult] {
        return try await fts5Search.searchByCategory(category, limit: limit)
    }

    /// Get search suggestions (autocomplete)
    func suggestions(for prefix: String, limit: Int = 10) async throws -> [String] {
        return try await fts5Search.suggestions(for: prefix, limit: limit)
    }

    /// Find similar items to a given item
    func findSimilar(to itemId: Int64, limit: Int = 10) async throws -> [SearchResult] {
        return try await vectorStore.findSimilarItems(to: itemId, limit: limit)
    }

    /// Get all categories
    func getCategories() async throws -> [String] {
        return try await itemService.fetchCategories()
    }

    // MARK: - Statistics

    /// Get search statistics
    func getSearchStats() async throws -> SearchStats {
        let vectorStats = try await vectorStore.getStats()

        return SearchStats(
            totalItems: vectorStats.totalItems,
            fts5Indexed: vectorStats.totalItems, // Auto-indexed
            vectorsIndexed: vectorStats.totalVectors,
            vectorCoverage: vectorStats.coverage,
            avgVectorDimension: vectorStats.avgDimension
        )
    }

    // MARK: - Helpers

    /// Determine optimal search mode based on query
    private func determineSearchMode(_ query: String) -> SearchMode {
        let words = query.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Exact SKU pattern (uppercase letters + numbers)
        let skuPattern = #"^[A-Z]{2,}[A-Z0-9\-]{2,}$"#
        if words.count == 1, let _ = query.range(of: skuPattern, options: .regularExpression) {
            return .fullText
        }

        // Single word queries: prefer FTS5
        if words.count == 1 {
            return .fullText
        }

        // Multi-word queries: use hybrid for better semantic understanding
        if words.count >= 3 {
            return .hybrid
        }

        // Default: full-text search
        return .fullText
    }
}

// MARK: - Search Mode

enum SearchMode {
    case auto // Automatically determine best mode
    case fullText // FTS5 only
    case semantic // Vector only
    case hybrid // Combined FTS5 + Vector
}

// MARK: - Stats

struct IndexStats {
    let itemsIndexed: Int
    let duration: TimeInterval
    let fts5Enabled: Bool
    let vectorsEnabled: Bool
}

struct SearchStats {
    let totalItems: Int
    let fts5Indexed: Int
    let vectorsIndexed: Int
    let vectorCoverage: Double
    let avgVectorDimension: Int

    var summary: String {
        """
        Total Items: \(totalItems)
        FTS5 Indexed: \(fts5Indexed)
        Vectors Indexed: \(vectorsIndexed)
        Vector Coverage: \(String(format: "%.1f%%", vectorCoverage * 100))
        Vector Dimension: \(avgVectorDimension)
        """
    }
}
