import SwiftUI

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @State private var showingAddStock = false

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading inventory...")
                } else if viewModel.stockItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("No Inventory")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Add stock items to get started")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Summary Section
                        Section {
                            SummaryRow(
                                title: "Total Items",
                                value: "\(viewModel.stockItems.count)",
                                icon: "cube.fill",
                                color: .blue
                            )
                            SummaryRow(
                                title: "Total Units",
                                value: "\(viewModel.totalQuantity)",
                                icon: "number",
                                color: .green
                            )
                            SummaryRow(
                                title: "Low Stock",
                                value: "\(viewModel.lowStockCount)",
                                icon: "exclamationmark.triangle.fill",
                                color: .orange
                            )
                            SummaryRow(
                                title: "Out of Stock",
                                value: "\(viewModel.outOfStockCount)",
                                icon: "xmark.circle.fill",
                                color: .red
                            )
                        } header: {
                            Text("Summary")
                        }

                        // Filter Section
                        Section {
                            Picker("Filter", selection: $viewModel.filterOption) {
                                Text("All").tag(FilterOption.all)
                                Text("Low Stock").tag(FilterOption.lowStock)
                                Text("Out of Stock").tag(FilterOption.outOfStock)
                                Text("Normal").tag(FilterOption.normal)
                            }
                            .pickerStyle(.segmented)

                            if !viewModel.locations.isEmpty {
                                Picker("Location", selection: $viewModel.selectedLocation) {
                                    Text("All Locations").tag(nil as String?)
                                    ForEach(viewModel.locations, id: \.self) { location in
                                        Text(location).tag(location as String?)
                                    }
                                }
                            }
                        } header: {
                            Text("Filters")
                        }

                        // Stock Items
                        Section {
                            ForEach(viewModel.filteredStockItems) { stockItem in
                                NavigationLink(destination: StockDetailView(stockWithItem: stockItem)) {
                                    StockRow(stockWithItem: stockItem)
                                }
                            }
                        } header: {
                            HStack {
                                Text("Stock Items")
                                Spacer()
                                Text("\(viewModel.filteredStockItems.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inventory")
            .searchable(text: $viewModel.searchText, prompt: "Search items...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddStock = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showingAddStock) {
                AddStockView {
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Stock Row

struct StockRow: View {
    let stockWithItem: StockWithItem

    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Image(systemName: stockWithItem.stockStatus.icon)
                .foregroundColor(Color(stockWithItem.stockStatus.color))
                .font(.title3)

            // Item Info
            VStack(alignment: .leading, spacing: 4) {
                Text(stockWithItem.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(stockWithItem.sku)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let category = stockWithItem.category {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let location = stockWithItem.location {
                        Text("•")
                            .foregroundColor(.secondary)
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Quantity
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stockWithItem.quantity)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(stockWithItem.isLowStock ? .orange : .primary)

                if let minQty = stockWithItem.minQuantity {
                    Text("min: \(minQty)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - ViewModel

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var stockItems: [StockWithItem] = []
    @Published var searchText = ""
    @Published var filterOption: FilterOption = .all
    @Published var selectedLocation: String?
    @Published var locations: [String] = []
    @Published var isLoading = false

    private let stockService = StockService()

    var filteredStockItems: [StockWithItem] {
        var items = stockItems

        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { stock in
                stock.name.localizedCaseInsensitiveContains(searchText) ||
                stock.sku.localizedCaseInsensitiveContains(searchText) ||
                stock.category?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        // Apply status filter
        switch filterOption {
        case .all:
            break
        case .lowStock:
            items = items.filter { $0.isLowStock && !$0.isOutOfStock }
        case .outOfStock:
            items = items.filter { $0.isOutOfStock }
        case .normal:
            items = items.filter { !$0.isLowStock && !$0.isOutOfStock }
        }

        // Apply location filter
        if let location = selectedLocation {
            items = items.filter { $0.location == location }
        }

        return items
    }

    var totalQuantity: Int {
        stockItems.reduce(0) { $0 + $1.quantity }
    }

    var lowStockCount: Int {
        stockItems.filter { $0.isLowStock && !$0.isOutOfStock }.count
    }

    var outOfStockCount: Int {
        stockItems.filter { $0.isOutOfStock }.count
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            stockItems = try await stockService.fetchAllWithItems()
            locations = try await stockService.fetchLocations()
        } catch {
            print("Failed to load inventory: \(error)")
        }
    }

    func refresh() async {
        await loadData()
    }
}

// MARK: - Filter Option

enum FilterOption {
    case all
    case lowStock
    case outOfStock
    case normal
}

// MARK: - Preview

struct InventoryView_Previews: PreviewProvider {
    static var previews: some View {
        InventoryView()
    }
}
