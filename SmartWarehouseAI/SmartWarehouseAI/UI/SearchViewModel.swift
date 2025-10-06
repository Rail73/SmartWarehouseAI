//
//  SearchViewModel.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import SwiftUI

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchMode: SearchMode = .auto
    @Published var searchResults: [SearchResult] = []
    @Published var isSearching = false
    @Published var showStats = false
    @Published var searchStats: SearchStats?
    @Published var lastSearchDuration: TimeInterval = 0

    private let searchService = SearchService()
    private var searchTask: Task<Void, Never>?

    // MARK: - Initialization

    func initialize() async {
        do {
            try await searchService.initialize()
            await updateStats()
        } catch {
            print("❌ Failed to initialize search: \(error)")
        }
    }

    // MARK: - Search

    func performSearch() async {
        // Cancel previous search
        searchTask?.cancel()

        guard !searchText.isEmpty else {
            searchResults = []
            lastSearchDuration = 0
            return
        }

        searchTask = Task {
            isSearching = true
            defer { isSearching = false }

            let startTime = Date()

            do {
                // Debounce: wait 300ms
                try await Task.sleep(nanoseconds: 300_000_000)

                guard !Task.isCancelled else { return }

                let results = try await searchService.search(
                    query: searchText,
                    mode: searchMode,
                    limit: 50
                )

                guard !Task.isCancelled else { return }

                searchResults = results
                lastSearchDuration = Date().timeIntervalSince(startTime)

                // Update stats if visible
                if showStats {
                    await updateStats()
                }
            } catch {
                if !Task.isCancelled {
                    print("❌ Search failed: \(error)")
                    searchResults = []
                }
            }
        }

        await searchTask?.value
    }

    // MARK: - Actions

    func reindexAll() async {
        isSearching = true
        defer { isSearching = false }

        do {
            let stats = try await searchService.indexAll()
            print("✅ Reindexed \(stats.itemsIndexed) items in \(String(format: "%.2f", stats.duration))s")
            await updateStats()
        } catch {
            print("❌ Reindex failed: \(error)")
        }
    }

    func updateStats() async {
        do {
            searchStats = try await searchService.getSearchStats()
        } catch {
            print("❌ Failed to load stats: \(error)")
        }
    }

    // MARK: - Observers

    func onSearchTextChange() {
        Task {
            await performSearch()
        }
    }

    func onSearchModeChange() {
        Task {
            await performSearch()
        }
    }
}

// MARK: - SearchMode Extensions

extension SearchMode: CaseIterable {
    static var allCases: [SearchMode] {
        [.auto, .fullText, .semantic, .hybrid]
    }

    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .fullText: return "Text"
        case .semantic: return "Semantic"
        case .hybrid: return "Hybrid"
        }
    }
}
