import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showingScanner = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search mode picker
                Picker("Search Mode", selection: $viewModel.searchMode) {
                    ForEach(SearchMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Results list
                if viewModel.isSearching {
                    ProgressView("Searching...")
                        .padding()
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                    emptyStateView
                } else if !viewModel.searchResults.isEmpty {
                    List {
                        // Stats section
                        if viewModel.showStats {
                            statsSection
                        }

                        // Results section
                        ForEach(viewModel.searchResults) { result in
                            SearchResultRow(result: result)
                        }
                    }
                } else {
                    initialStateView
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search items...")
            .onChange(of: viewModel.searchText) { _ in
                viewModel.onSearchTextChange()
            }
            .onChange(of: viewModel.searchMode) { _ in
                viewModel.onSearchModeChange()
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingScanner = true
                    } label: {
                        Image(systemName: "barcode.viewfinder")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { viewModel.showStats.toggle() }) {
                            Label(viewModel.showStats ? "Hide Stats" : "Show Stats", systemImage: "chart.bar")
                        }

                        Button(action: { Task { await viewModel.reindexAll() } }) {
                            Label("Reindex All", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { scannedCode in
                    // Handle scanned code
                    viewModel.searchText = scannedCode
                    showingScanner = false
                }
            }
            .task {
                await viewModel.initialize()
            }
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    private var initialStateView: some View {
        VStack(spacing: 30) {
            Image(systemName: "magnifyingglass.circle")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.3))

            VStack(spacing: 12) {
                Text("Smart Search")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Search using natural language or exact terms")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "text.magnifyingglass", title: "Full-text search", subtitle: "Fast keyword matching")
                FeatureRow(icon: "brain", title: "Semantic search", subtitle: "Find similar items by meaning")
                FeatureRow(icon: "sparkles", title: "Hybrid search", subtitle: "Best of both worlds")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Spacer()
        }
        .padding()
    }

    private var statsSection: some View {
        Section("Search Statistics") {
            if let stats = viewModel.searchStats {
                VStack(alignment: .leading, spacing: 8) {
                    StatRow(label: "Total Items", value: "\(stats.totalItems)")
                    StatRow(label: "FTS5 Indexed", value: "\(stats.fts5Indexed)")
                    StatRow(label: "Vectors Indexed", value: "\(stats.vectorsIndexed)")
                    StatRow(label: "Vector Coverage", value: String(format: "%.1f%%", stats.vectorCoverage * 100))

                    if viewModel.lastSearchDuration > 0 {
                        StatRow(label: "Last Search", value: String(format: "%.0fms", viewModel.lastSearchDuration * 1000))
                    }
                }
                .font(.caption)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with match type and score
            HStack {
                Label(result.matchType.rawValue, systemImage: matchTypeIcon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(matchTypeColor.opacity(0.2))
                    .foregroundColor(matchTypeColor)
                    .cornerRadius(4)

                Spacer()

                // Score indicator
                ScoreIndicator(score: result.score)
            }

            // Item name
            if let snippet = result.nameSnippet {
                Text(snippet.replacingOccurrences(of: "<b>", with: "")
                    .replacingOccurrences(of: "</b>", with: ""))
                    .font(.headline)
            } else {
                Text(result.item.name)
                    .font(.headline)
            }

            // SKU and category
            HStack {
                Text(result.item.sku)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let category = result.item.category {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Description snippet
            if let snippet = result.descriptionSnippet {
                Text(snippet.replacingOccurrences(of: "<b>", with: "")
                    .replacingOccurrences(of: "</b>", with: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else if let description = result.item.itemDescription {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var matchTypeIcon: String {
        switch result.matchType {
        case .fullText: return "text.magnifyingglass"
        case .vector: return "brain"
        case .hybrid: return "sparkles"
        case .category: return "folder"
        case .exact: return "checkmark.circle"
        }
    }

    private var matchTypeColor: Color {
        switch result.matchType {
        case .fullText: return .blue
        case .vector: return .purple
        case .hybrid: return .green
        case .category: return .orange
        case .exact: return .blue
        }
    }
}

struct ScoreIndicator: View {
    let score: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < filledCircles ? Color.yellow : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var filledCircles: Int {
        Int(score * 5)
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}
