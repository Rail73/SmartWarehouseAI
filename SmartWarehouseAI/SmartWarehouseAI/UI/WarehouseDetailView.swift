//
//  WarehouseDetailView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct WarehouseDetailView: View {
    let warehouseId: Int64
    @StateObject private var viewModel: WarehouseDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingQRCode = false
    @State private var showingScanner = false
    @State private var searchText = ""

    init(warehouseId: Int64) {
        self.warehouseId = warehouseId
        _viewModel = StateObject(wrappedValue: WarehouseDetailViewModel(warehouseId: warehouseId))
    }

    var body: some View {
        Form {
            if let warehouse = viewModel.warehouse {
                // Warehouse Information
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(warehouse.name)
                            .foregroundColor(.secondary)
                    }

                    if let description = warehouse.warehouseDescription {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .foregroundColor(.secondary)
                            Text(description)
                        }
                    }
                } header: {
                    Text("Warehouse Information")
                }

                // Statistics
                Section {
                    HStack {
                        Text("Total Items")
                        Spacer()
                        Text("\(viewModel.stockItems.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Total Quantity")
                        Spacer()
                        Text("\(viewModel.totalQuantity)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Low Stock Items")
                        Spacer()
                        Text("\(viewModel.lowStockCount)")
                            .foregroundColor(viewModel.lowStockCount > 0 ? .orange : .secondary)
                    }

                    HStack {
                        Text("Out of Stock")
                        Spacer()
                        Text("\(viewModel.outOfStockCount)")
                            .foregroundColor(viewModel.outOfStockCount > 0 ? .red : .secondary)
                    }
                } header: {
                    Text("Statistics")
                }

                // Actions
                Section {
                    Button {
                        showingQRCode = true
                    } label: {
                        HStack {
                            Image(systemName: "qrcode")
                            Text("Show QR Code")
                        }
                    }

                    Button {
                        showingScanner = true
                    } label: {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                            Text("Scan Item")
                        }
                    }
                } header: {
                    Text("Actions")
                }

                // Stock Items
                Section {
                    if viewModel.stockItems.isEmpty {
                        Text("No items in this warehouse")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredStockItems) { stockWithItem in
                            NavigationLink(destination: ItemDetailView(itemId: stockWithItem.item.id!)) {
                                StockItemRow(stockWithItem: stockWithItem)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Stock Items")
                        Spacer()
                        if !viewModel.stockItems.isEmpty {
                            Text("\(filteredStockItems.count) items")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Metadata
                Section {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(warehouse.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(warehouse.updatedAt, style: .relative)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Metadata")
                }
            } else if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Warehouse Details")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search items")
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(
                qrType: .warehouse(warehouseId),
                title: "Warehouse QR Code"
            )
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView { result in
                showingScanner = false
                // Handle scanned item - add to this warehouse
                viewModel.handleScannedItem(result)
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
    }

    private var filteredStockItems: [StockWithItem] {
        if searchText.isEmpty {
            return viewModel.stockItems
        } else {
            return viewModel.stockItems.filter { stockWithItem in
                stockWithItem.name.localizedCaseInsensitiveContains(searchText) ||
                stockWithItem.sku.localizedCaseInsensitiveContains(searchText) ||
                (stockWithItem.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}

// MARK: - Stock Item Row

struct StockItemRow: View {
    let stockWithItem: StockWithItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stockWithItem.name)
                    .font(.headline)

                Text(stockWithItem.sku)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                if let category = stockWithItem.category {
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: stockWithItem.stockStatus.icon)
                        .foregroundColor(Color(stockWithItem.stockStatus.color))
                        .font(.caption)
                    Text("\(stockWithItem.quantity)")
                        .font(.headline)
                }

                if let min = stockWithItem.minQuantity, let max = stockWithItem.maxQuantity {
                    Text("\(min)-\(max)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

@MainActor
class WarehouseDetailViewModel: ObservableObject {
    private let warehouseId: Int64
    private let warehouseService = WarehouseService()

    @Published var warehouse: Warehouse?
    @Published var stockItems: [StockWithItem] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    var totalQuantity: Int {
        stockItems.reduce(0) { $0 + $1.quantity }
    }

    var lowStockCount: Int {
        stockItems.filter { $0.isLowStock }.count
    }

    var outOfStockCount: Int {
        stockItems.filter { $0.isOutOfStock }.count
    }

    init(warehouseId: Int64) {
        self.warehouseId = warehouseId
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let warehouseWithItems = try await warehouseService.fetchWarehouseWithItems(warehouseId)

            if let data = warehouseWithItems {
                warehouse = data.warehouse
                stockItems = data.stockItems
            } else {
                errorMessage = "Warehouse not found"
                showError = true
            }
        } catch {
            errorMessage = "Failed to load warehouse: \(error.localizedDescription)"
            showError = true
        }
    }

    func handleScannedItem(_ result: String) {
        // TODO: Implement item scanning logic
        // 1. Parse barcode/QR result
        // 2. Find item by barcode or QR
        // 3. Add item to this warehouse or update stock
        print("Scanned: \(result)")
    }
}

// MARK: - Preview

struct WarehouseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WarehouseDetailView(warehouseId: 1)
        }
    }
}
