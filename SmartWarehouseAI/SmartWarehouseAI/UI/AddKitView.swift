//
//  AddKitView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct AddKitView: View {
    @StateObject private var viewModel = AddKitViewModel()
    @Environment(\.dismiss) private var dismiss
    let onKitAdded: () -> Void

    var body: some View {
        NavigationView {
            Form {
                // Basic Information
                Section {
                    TextField("Kit Name", text: $viewModel.name)
                        .textInputAutocapitalization(.words)

                    TextField("SKU", text: $viewModel.sku)
                        .textInputAutocapitalization(.characters)

                    TextEditor(text: $viewModel.description)
                        .frame(minHeight: 60, maxHeight: 120)
                        .overlay(
                            Group {
                                if viewModel.description.isEmpty {
                                    Text("Description (optional)")
                                        .foregroundColor(Color(.placeholderText))
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                } header: {
                    Text("Kit Information")
                }

                // Parts Selection
                Section {
                    ForEach(viewModel.selectedParts) { part in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(part.item.name)
                                    .font(.headline)
                                Text(part.item.sku)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Stepper(
                                "\(part.quantity)",
                                value: Binding(
                                    get: { part.quantity },
                                    set: { newValue in
                                        viewModel.updatePartQuantity(itemId: part.item.id!, quantity: newValue)
                                    }
                                ),
                                in: 1...999
                            )
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.removePart(itemId: part.item.id!)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }

                    if !viewModel.availableItems.isEmpty {
                        Menu {
                            ForEach(viewModel.availableItems) { item in
                                Button {
                                    viewModel.addPart(item: item)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(item.name)
                                        Text(item.sku)
                                            .font(.caption)
                                    }
                                }
                            }
                        } label: {
                            Label("Add Part", systemImage: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    } else if viewModel.selectedParts.isEmpty {
                        Text("No items available")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    HStack {
                        Text("Parts")
                        Spacer()
                        Text("\(viewModel.selectedParts.count)")
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("Add items that make up this kit")
                }

                // Preview
                if !viewModel.selectedParts.isEmpty {
                    Section {
                        HStack {
                            Text("Kit Name")
                            Spacer()
                            Text(viewModel.name.isEmpty ? "N/A" : viewModel.name)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("SKU")
                            Spacer()
                            Text(viewModel.sku.isEmpty ? "N/A" : viewModel.sku)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Total Parts")
                            Spacer()
                            Text("\(viewModel.selectedParts.count)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Total Items")
                            Spacer()
                            Text("\(viewModel.totalItemCount)")
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Preview")
                    }
                }
            }
            .navigationTitle("Add Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.save()
                            onKitAdded()
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
class AddKitViewModel: ObservableObject {
    @Published var name = ""
    @Published var sku = ""
    @Published var description = ""

    @Published var availableItems: [Item] = []
    @Published var selectedParts: [SelectedPart] = []

    @Published var showError = false
    @Published var errorMessage: String?

    private let itemService = ItemService()
    private let kitService = KitService()

    struct SelectedPart: Identifiable {
        let item: Item
        var quantity: Int

        var id: Int64 { item.id! }
    }

    var isValid: Bool {
        !name.isEmpty && !sku.isEmpty && !selectedParts.isEmpty
    }

    var totalItemCount: Int {
        selectedParts.reduce(0) { $0 + $1.quantity }
    }

    func loadData() async {
        do {
            availableItems = try await itemService.fetchAll()
        } catch {
            errorMessage = "Failed to load items: \(error.localizedDescription)"
            showError = true
        }
    }

    func addPart(item: Item) {
        guard !selectedParts.contains(where: { $0.item.id == item.id }) else {
            return
        }

        selectedParts.append(SelectedPart(item: item, quantity: 1))
        availableItems.removeAll { $0.id == item.id }
    }

    func removePart(itemId: Int64) {
        if let index = selectedParts.firstIndex(where: { $0.item.id == itemId }) {
            let part = selectedParts.remove(at: index)
            availableItems.append(part.item)
            availableItems.sort { $0.name < $1.name }
        }
    }

    func updatePartQuantity(itemId: Int64, quantity: Int) {
        if let index = selectedParts.firstIndex(where: { $0.item.id == itemId }) {
            selectedParts[index].quantity = max(1, quantity)
        }
    }

    func save() async {
        guard isValid else {
            errorMessage = "Please fill in all required fields"
            showError = true
            return
        }

        do {
            // Create kit
            let kit = Kit(
                name: name,
                kitDescription: description.isEmpty ? nil : description,
                sku: sku
            )

            let savedKit = try await kitService.create(kit)

            guard let kitId = savedKit.id else {
                throw NSError(domain: "AddKitViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get kit ID"])
            }

            // Add parts
            for part in selectedParts {
                guard let itemId = part.item.id else { continue }
                _ = try await kitService.addPart(kitId: kitId, itemId: itemId, quantity: part.quantity)
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Preview

struct AddKitView_Previews: PreviewProvider {
    static var previews: some View {
        AddKitView {
            print("Kit added")
        }
    }
}
