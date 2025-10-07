//
//  WarehousesView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct WarehousesView: View {
    @StateObject private var viewModel = WarehousesViewModel()
    @State private var showingAddWarehouse = false
    @State private var searchText = ""

    var body: some View {
        NavigationView {
            List {
                // Summary Section
                if !viewModel.warehouses.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.blue)
                                Text("Total Warehouses")
                                Spacer()
                                Text("\(viewModel.warehouses.count)")
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Image(systemName: "shippingbox")
                                    .foregroundColor(.green)
                                Text("Total Items")
                                Spacer()
                                Text("\(viewModel.totalItems)")
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Image(systemName: "number")
                                    .foregroundColor(.purple)
                                Text("Total Quantity")
                                Spacer()
                                Text("\(viewModel.totalQuantity)")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.subheadline)
                    } header: {
                        Text("Summary")
                    }
                }

                // Warehouses List
                Section {
                    if viewModel.warehouses.isEmpty {
                        if viewModel.isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "building.2")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No Warehouses")
                                    .font(.headline)
                                Text("Add your first warehouse to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                        }
                    } else {
                        ForEach(filteredWarehouses) { warehouse in
                            NavigationLink(destination: WarehouseDetailView(warehouseId: warehouse.id!)) {
                                WarehouseRow(warehouse: warehouse)
                            }
                        }
                        .onDelete(perform: deleteWarehouses)
                    }
                } header: {
                    Text("Warehouses")
                }
            }
            .navigationTitle("Warehouses")
            .searchable(text: $searchText, prompt: "Search warehouses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddWarehouse = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddWarehouse) {
                AddWarehouseView { newWarehouse in
                    Task {
                        await viewModel.addWarehouse(newWarehouse)
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
            .task {
                await viewModel.loadWarehouses()
            }
            .refreshable {
                await viewModel.loadWarehouses()
            }
        }
    }

    private var filteredWarehouses: [Warehouse] {
        if searchText.isEmpty {
            return viewModel.warehouses
        } else {
            return viewModel.warehouses.filter { warehouse in
                warehouse.name.localizedCaseInsensitiveContains(searchText) ||
                (warehouse.warehouseDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    private func deleteWarehouses(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let warehouse = viewModel.warehouses[index]
                if let id = warehouse.id {
                    await viewModel.deleteWarehouse(id)
                }
            }
        }
    }
}

// MARK: - Warehouse Row

struct WarehouseRow: View {
    let warehouse: Warehouse

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(warehouse.name)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let description = warehouse.warehouseDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            HStack {
                Text("Updated: \(warehouse.updatedAt, style: .relative)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

@MainActor
class WarehousesViewModel: ObservableObject {
    private let warehouseService = WarehouseService()
    private let stockService = StockService()

    @Published var warehouses: [Warehouse] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    var totalItems: Int {
        // Count unique items across all warehouses
        // This is an approximation - actual implementation would need JOIN
        0 // Placeholder - will be calculated on detail view
    }

    var totalQuantity: Int {
        // Total quantity across all warehouses
        // This is an approximation - actual implementation would need JOIN
        0 // Placeholder - will be calculated on detail view
    }

    func loadWarehouses() async {
        isLoading = true
        defer { isLoading = false }

        do {
            warehouses = try await warehouseService.fetchAll()
        } catch {
            errorMessage = "Failed to load warehouses: \(error.localizedDescription)"
            showError = true
        }
    }

    func addWarehouse(_ warehouse: Warehouse) async {
        do {
            let created = try await warehouseService.create(warehouse)
            warehouses.append(created)
            warehouses.sort { $0.name < $1.name }
        } catch {
            errorMessage = "Failed to add warehouse: \(error.localizedDescription)"
            showError = true
        }
    }

    func deleteWarehouse(_ id: Int64) async {
        do {
            try await warehouseService.delete(id)
            warehouses.removeAll { $0.id == id }
        } catch {
            errorMessage = "Failed to delete warehouse: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Preview

struct WarehousesView_Previews: PreviewProvider {
    static var previews: some View {
        WarehousesView()
    }
}
