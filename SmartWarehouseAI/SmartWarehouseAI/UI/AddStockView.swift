//
//  AddStockView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct AddStockView: View {
    @StateObject private var viewModel = AddStockViewModel()
    @Environment(\.dismiss) private var dismiss
    let onStockAdded: () -> Void

    var body: some View {
        NavigationView {
            Form {
                // Item Selection
                Section {
                    if viewModel.availableItems.isEmpty {
                        Text("No items available")
                            .foregroundColor(.secondary)
                    } else {
                        Picker("Select Item", selection: $viewModel.selectedItem) {
                            Text("Choose an item...").tag(nil as Item?)
                            ForEach(viewModel.availableItems) { item in
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text(item.sku)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(item as Item?)
                            }
                        }

                        if let item = viewModel.selectedItem {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.headline)
                                Text("SKU: \(item.sku)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if let category = item.category {
                                    Text("Category: \(category)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Item")
                } footer: {
                    Text("Select an item to add stock for")
                }

                // Quantity
                Section {
                    Stepper(
                        "Quantity: \(viewModel.quantity)",
                        value: $viewModel.quantity,
                        in: 0...99999,
                        step: 1
                    )

                    HStack {
                        Button("10") { viewModel.quantity = 10 }
                        Button("50") { viewModel.quantity = 50 }
                        Button("100") { viewModel.quantity = 100 }
                        Button("500") { viewModel.quantity = 500 }
                    }
                    .buttonStyle(.bordered)
                } header: {
                    Text("Quantity")
                }

                // Location
                Section {
                    TextField("Location (optional)", text: $viewModel.location)
                        .textInputAutocapitalization(.words)

                    if !viewModel.existingLocations.isEmpty {
                        Text("Existing Locations:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(viewModel.existingLocations, id: \.self) { location in
                                    Button(location) {
                                        viewModel.location = location
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Location")
                } footer: {
                    Text("Warehouse location (e.g., Shelf A-12, Zone B)")
                }

                // Thresholds
                Section {
                    Toggle("Set Min Quantity Alert", isOn: $viewModel.hasMinQuantity)

                    if viewModel.hasMinQuantity {
                        Stepper(
                            "Min: \(viewModel.minQuantity)",
                            value: $viewModel.minQuantity,
                            in: 0...99999
                        )
                    }

                    Toggle("Set Max Quantity Alert", isOn: $viewModel.hasMaxQuantity)

                    if viewModel.hasMaxQuantity {
                        Stepper(
                            "Max: \(viewModel.maxQuantity)",
                            value: $viewModel.maxQuantity,
                            in: 0...99999
                        )
                    }
                } header: {
                    Text("Thresholds")
                } footer: {
                    Text("Optional min/max quantity alerts")
                }

                // Preview
                if viewModel.selectedItem != nil {
                    Section {
                        HStack {
                            Text("Item")
                            Spacer()
                            Text(viewModel.selectedItem?.name ?? "")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Quantity")
                            Spacer()
                            Text("\(viewModel.quantity)")
                                .foregroundColor(.secondary)
                        }
                        if !viewModel.location.isEmpty {
                            HStack {
                                Text("Location")
                                Spacer()
                                Text(viewModel.location)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if viewModel.hasMinQuantity {
                            HStack {
                                Text("Min Alert")
                                Spacer()
                                Text("\(viewModel.minQuantity)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        if viewModel.hasMaxQuantity {
                            HStack {
                                Text("Max Alert")
                                Spacer()
                                Text("\(viewModel.maxQuantity)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Preview")
                    }
                }
            }
            .navigationTitle("Add Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await viewModel.save()
                            onStockAdded()
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - ViewModel

@MainActor
class AddStockViewModel: ObservableObject {
    @Published var availableItems: [Item] = []
    @Published var existingLocations: [String] = []

    @Published var selectedItem: Item?
    @Published var quantity: Int = 0
    @Published var location: String = ""
    @Published var minQuantity: Int = 10
    @Published var maxQuantity: Int = 100
    @Published var hasMinQuantity: Bool = false
    @Published var hasMaxQuantity: Bool = false

    @Published var showError = false
    @Published var errorMessage: String?

    private let itemService = ItemService()
    private let stockService = StockService()

    var isValid: Bool {
        selectedItem != nil && quantity > 0
    }

    func loadData() async {
        do {
            // Load all items
            let allItems = try await itemService.fetchAll()

            // Load existing stocks to filter out items that already have stock
            let existingStocks = try await stockService.fetchAll()
            let itemsWithStock = Set(existingStocks.map { $0.itemId })

            // Filter to only show items without stock
            availableItems = allItems.filter { item in
                guard let itemId = item.id else { return false }
                return !itemsWithStock.contains(itemId)
            }

            // Load existing locations
            existingLocations = try await stockService.fetchLocations()
        } catch {
            errorMessage = "Failed to load items: \(error.localizedDescription)"
            showError = true
        }
    }

    func save() async {
        guard let item = selectedItem, let itemId = item.id else {
            errorMessage = "Please select an item"
            showError = true
            return
        }

        do {
            let stock = Stock(
                itemId: itemId,
                quantity: quantity,
                location: location.isEmpty ? nil : location,
                minQuantity: hasMinQuantity ? minQuantity : nil,
                maxQuantity: hasMaxQuantity ? maxQuantity : nil
            )

            _ = try await stockService.create(stock)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Preview

struct AddStockView_Previews: PreviewProvider {
    static var previews: some View {
        AddStockView {
            print("Stock added")
        }
    }
}
