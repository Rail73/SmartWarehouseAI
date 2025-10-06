//
//  StockDetailView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct StockDetailView: View {
    let stockWithItem: StockWithItem
    @StateObject private var viewModel: StockDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(stockWithItem: StockWithItem) {
        self.stockWithItem = stockWithItem
        _viewModel = StateObject(wrappedValue: StockDetailViewModel(stockWithItem: stockWithItem))
    }

    var body: some View {
        Form {
            // Item Information (Read-only)
            Section {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(stockWithItem.name)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("SKU")
                    Spacer()
                    Text(stockWithItem.sku)
                        .foregroundColor(.secondary)
                }
                if let category = stockWithItem.category {
                    HStack {
                        Text("Category")
                        Spacer()
                        Text(category)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Item Information")
            }

            // Stock Status
            Section {
                HStack {
                    Label(
                        stockWithItem.stockStatus.label,
                        systemImage: stockWithItem.stockStatus.icon
                    )
                    .foregroundColor(Color(stockWithItem.stockStatus.color))

                    Spacer()

                    Text(stockWithItem.stockStatus.label)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(stockWithItem.stockStatus.color).opacity(0.2))
                        .cornerRadius(8)
                }
            } header: {
                Text("Status")
            }

            // Quantity Management
            Section {
                HStack {
                    Text("Current Quantity")
                    Spacer()
                    Text("\(viewModel.quantity)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }

                Stepper(
                    "Adjust Quantity",
                    value: $viewModel.quantity,
                    in: 0...99999
                )

                HStack {
                    Button {
                        viewModel.showAdjustmentSheet = true
                    } label: {
                        Label("Quick Adjust", systemImage: "plus.forwardslash.minus")
                    }

                    Spacer()
                }
            } header: {
                Text("Quantity")
            } footer: {
                Text("Use stepper for small changes or Quick Adjust for larger changes")
            }

            // Location
            Section {
                TextField("Location", text: $viewModel.location)
                    .textInputAutocapitalization(.words)
            } header: {
                Text("Location")
            } footer: {
                Text("Warehouse location (e.g., Shelf A-12, Zone B)")
            }

            // Min/Max Thresholds
            Section {
                Toggle("Enable Min Threshold", isOn: $viewModel.hasMinQuantity)

                if viewModel.hasMinQuantity {
                    Stepper(
                        "Min Quantity: \(viewModel.minQuantity ?? 0)",
                        value: Binding(
                            get: { viewModel.minQuantity ?? 0 },
                            set: { viewModel.minQuantity = $0 }
                        ),
                        in: 0...99999
                    )
                }

                Toggle("Enable Max Threshold", isOn: $viewModel.hasMaxQuantity)

                if viewModel.hasMaxQuantity {
                    Stepper(
                        "Max Quantity: \(viewModel.maxQuantity ?? 0)",
                        value: Binding(
                            get: { viewModel.maxQuantity ?? 0 },
                            set: { viewModel.maxQuantity = $0 }
                        ),
                        in: 0...99999
                    )
                }
            } header: {
                Text("Thresholds")
            } footer: {
                Text("Set min/max quantity alerts for inventory management")
            }

            // Metadata
            Section {
                HStack {
                    Text("Last Updated")
                    Spacer()
                    Text(viewModel.updatedAt, style: .relative)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Metadata")
            }
        }
        .navigationTitle("Stock Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await viewModel.save()
                        dismiss()
                    }
                }
                .disabled(!viewModel.hasChanges)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $viewModel.showAdjustmentSheet) {
            QuickAdjustmentView(currentQuantity: viewModel.quantity) { newQuantity in
                viewModel.quantity = newQuantity
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
}

// MARK: - ViewModel

@MainActor
class StockDetailViewModel: ObservableObject {
    private let stockWithItem: StockWithItem
    private let stockService = StockService()

    @Published var quantity: Int
    @Published var location: String
    @Published var minQuantity: Int?
    @Published var maxQuantity: Int?
    @Published var hasMinQuantity: Bool
    @Published var hasMaxQuantity: Bool
    @Published var updatedAt: Date

    @Published var showAdjustmentSheet = false
    @Published var showError = false
    @Published var errorMessage: String?

    private var initialQuantity: Int
    private var initialLocation: String
    private var initialMinQuantity: Int?
    private var initialMaxQuantity: Int?

    init(stockWithItem: StockWithItem) {
        self.stockWithItem = stockWithItem

        // Initialize current values
        self.quantity = stockWithItem.quantity
        self.location = stockWithItem.location ?? ""
        self.minQuantity = stockWithItem.minQuantity
        self.maxQuantity = stockWithItem.maxQuantity
        self.hasMinQuantity = stockWithItem.minQuantity != nil
        self.hasMaxQuantity = stockWithItem.maxQuantity != nil
        self.updatedAt = stockWithItem.updatedAt

        // Store initial values
        self.initialQuantity = stockWithItem.quantity
        self.initialLocation = stockWithItem.location ?? ""
        self.initialMinQuantity = stockWithItem.minQuantity
        self.initialMaxQuantity = stockWithItem.maxQuantity
    }

    var hasChanges: Bool {
        quantity != initialQuantity ||
        location != initialLocation ||
        minQuantity != initialMinQuantity ||
        maxQuantity != initialMaxQuantity
    }

    func save() async {
        do {
            var updatedStock = stockWithItem.stock
            updatedStock.quantity = quantity
            updatedStock.location = location.isEmpty ? nil : location
            updatedStock.minQuantity = hasMinQuantity ? minQuantity : nil
            updatedStock.maxQuantity = hasMaxQuantity ? maxQuantity : nil

            try await stockService.update(updatedStock)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Quick Adjustment View

struct QuickAdjustmentView: View {
    @Environment(\.dismiss) private var dismiss
    let currentQuantity: Int
    let onSave: (Int) -> Void

    @State private var adjustmentType: AdjustmentType = .add
    @State private var adjustmentAmount: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Operation", selection: $adjustmentType) {
                        Text("Add").tag(AdjustmentType.add)
                        Text("Subtract").tag(AdjustmentType.subtract)
                        Text("Set To").tag(AdjustmentType.set)
                    }
                    .pickerStyle(.segmented)

                    TextField("Amount", text: $adjustmentAmount)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Adjustment")
                }

                Section {
                    HStack {
                        Text("Current Quantity")
                        Spacer()
                        Text("\(currentQuantity)")
                            .foregroundColor(.secondary)
                    }

                    if let amount = Int(adjustmentAmount) {
                        HStack {
                            Text("New Quantity")
                            Spacer()
                            Text("\(calculateNewQuantity(amount))")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Quick Adjust")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let amount = Int(adjustmentAmount) {
                            onSave(calculateNewQuantity(amount))
                            dismiss()
                        }
                    }
                    .disabled(adjustmentAmount.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func calculateNewQuantity(_ amount: Int) -> Int {
        switch adjustmentType {
        case .add:
            return max(0, currentQuantity + amount)
        case .subtract:
            return max(0, currentQuantity - amount)
        case .set:
            return max(0, amount)
        }
    }

    enum AdjustmentType {
        case add, subtract, set
    }
}

// MARK: - Preview

struct StockDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let item = Item(
            id: 1,
            name: "Test Item",
            sku: "TEST-001",
            itemDescription: "Test description",
            category: "Test Category"
        )

        let stock = Stock(
            id: 1,
            itemId: 1,
            quantity: 50,
            location: "Shelf A-12",
            minQuantity: 10,
            maxQuantity: 100
        )

        let stockWithItem = StockWithItem(stock: stock, item: item)

        NavigationView {
            StockDetailView(stockWithItem: stockWithItem)
        }
    }
}
