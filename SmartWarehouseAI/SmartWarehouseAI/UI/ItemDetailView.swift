//
//  ItemDetailView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct ItemDetailView: View {
    let itemId: Int64
    @StateObject private var viewModel: ItemDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingQRCode = false

    init(itemId: Int64) {
        self.itemId = itemId
        _viewModel = StateObject(wrappedValue: ItemDetailViewModel(itemId: itemId))
    }

    var body: some View {
        Form {
            if let item = viewModel.item {
                // Item Information
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(item.name)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("SKU")
                        Spacer()
                        Text(item.sku)
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                    if let barcode = item.barcode {
                        HStack {
                            Text("Barcode")
                            Spacer()
                            Text(barcode)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    if let category = item.category {
                        HStack {
                            Text("Category")
                            Spacer()
                            Text(category)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let description = item.itemDescription {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .foregroundColor(.secondary)
                            Text(description)
                        }
                    }
                } header: {
                    Text("Item Information")
                }

                // Stock on Warehouses
                if !viewModel.stockItems.isEmpty {
                    Section {
                        ForEach(viewModel.stockItems, id: \.stock.id) { stockWithWarehouse in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stockWithWarehouse.warehouseName)
                                            .font(.headline)
                                        Text("Quantity: \(stockWithWarehouse.stock.quantity)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    // Status indicator
                                    Image(systemName: stockWithWarehouse.statusIcon)
                                        .foregroundColor(stockWithWarehouse.statusColor)
                                        .font(.title2)
                                }

                                if let minQty = stockWithWarehouse.stock.minQuantity,
                                   let maxQty = stockWithWarehouse.stock.maxQuantity {
                                    HStack(spacing: 8) {
                                        Text("Min: \(minQty)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text("Max: \(maxQty)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        HStack {
                            Text("Stock on Warehouses")
                            Spacer()
                            Text("\(viewModel.totalQuantity) total")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Section {
                        Text("No stock records")
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Stock on Warehouses")
                    }
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
                } header: {
                    Text("Actions")
                }

                // Metadata
                Section {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(item.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(item.updatedAt, style: .relative)
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
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingQRCode) {
            QRCodeView(
                qrType: .item(itemId),
                title: "Item QR Code"
            )
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
    }
}

// MARK: - ViewModel

@MainActor
class ItemDetailViewModel: ObservableObject {
    private let itemId: Int64
    private let itemService = ItemService()
    private let stockService = StockService()
    private let warehouseService = WarehouseService()

    @Published var item: Item?
    @Published var stockItems: [StockWithWarehouse] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    struct StockWithWarehouse {
        let stock: Stock
        let warehouseName: String

        var statusIcon: String {
            let qty = stock.quantity
            if qty == 0 {
                return "xmark.circle.fill"
            } else if let min = stock.minQuantity, qty <= min {
                return "exclamationmark.triangle.fill"
            } else if let max = stock.maxQuantity, qty > max {
                return "arrow.up.circle.fill"
            } else {
                return "checkmark.circle.fill"
            }
        }

        var statusColor: Color {
            let qty = stock.quantity
            if qty == 0 {
                return .red
            } else if let min = stock.minQuantity, qty <= min {
                return .orange
            } else if let max = stock.maxQuantity, qty > max {
                return .blue
            } else {
                return .green
            }
        }
    }

    var totalQuantity: Int {
        stockItems.reduce(0) { $0 + $1.stock.quantity }
    }

    init(itemId: Int64) {
        self.itemId = itemId
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch item
            item = try await itemService.fetch(by: itemId)

            // Fetch stock for this item
            let stocks = try await stockService.fetchByItem(itemId)

            // Fetch warehouse names
            var stocksWithWarehouses: [StockWithWarehouse] = []
            for stock in stocks {
                let warehouseName: String
                if let warehouseId = stock.warehouseId {
                    if let warehouse = try await warehouseService.fetch(warehouseId) {
                        warehouseName = warehouse.name
                    } else {
                        warehouseName = "Unknown Warehouse"
                    }
                } else if let location = stock.location {
                    warehouseName = location
                } else {
                    warehouseName = "No Location"
                }

                stocksWithWarehouses.append(StockWithWarehouse(
                    stock: stock,
                    warehouseName: warehouseName
                ))
            }

            stockItems = stocksWithWarehouses
        } catch {
            errorMessage = "Failed to load item: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Preview

struct ItemDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ItemDetailView(itemId: 1)
        }
    }
}
