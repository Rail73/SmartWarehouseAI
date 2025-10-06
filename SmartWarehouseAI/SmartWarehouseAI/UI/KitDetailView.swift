//
//  KitDetailView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct KitDetailView: View {
    let kitId: Int64
    @StateObject private var viewModel: KitDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAssembly = false
    @State private var showingDisassembly = false

    init(kitId: Int64) {
        self.kitId = kitId
        _viewModel = StateObject(wrappedValue: KitDetailViewModel(kitId: kitId))
    }

    var body: some View {
        Form {
            // Kit Information
            if let kitWithParts = viewModel.kitWithParts {
                Section {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(kitWithParts.kit.name)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("SKU")
                        Spacer()
                        Text(kitWithParts.kit.sku)
                            .foregroundColor(.secondary)
                    }
                    if let description = kitWithParts.kit.kitDescription {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .foregroundColor(.secondary)
                            Text(description)
                        }
                    }
                } header: {
                    Text("Kit Information")
                }

                // Availability Status
                Section {
                    HStack {
                        Label(
                            "Available Kits",
                            systemImage: availabilityIcon
                        )
                        .foregroundColor(availabilityColor)

                        Spacer()

                        Text("\(viewModel.availableQuantity)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(availabilityColor)
                    }

                    if !viewModel.shortages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Missing Items:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(viewModel.shortages, id: \.item.id) { shortage in
                                HStack {
                                    Text(shortage.item.name)
                                        .font(.caption)
                                    Spacer()
                                    Text("Need \(shortage.shortage) more")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Availability")
                }

                // Parts List
                Section {
                    ForEach(kitWithParts.parts, id: \.part.id) { partWithItem in
                        PartRow(partWithItem: partWithItem)
                    }
                } header: {
                    HStack {
                        Text("Parts")
                        Spacer()
                        Text("\(kitWithParts.parts.count)")
                            .foregroundColor(.secondary)
                    }
                }

                // Actions
                Section {
                    Button {
                        showingAssembly = true
                    } label: {
                        HStack {
                            Image(systemName: "hammer.fill")
                            Text("Assemble Kit")
                        }
                    }
                    .disabled(viewModel.availableQuantity == 0)

                    Button {
                        showingDisassembly = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.uturn.backward")
                            Text("Disassemble Kit")
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
                        Text(kitWithParts.kit.createdAt, style: .date)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(kitWithParts.kit.updatedAt, style: .relative)
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
        .navigationTitle("Kit Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAssembly) {
            AssembleKitView(
                kitId: kitId,
                availableQuantity: viewModel.availableQuantity
            ) {
                Task {
                    await viewModel.refresh()
                }
            }
        }
        .sheet(isPresented: $showingDisassembly) {
            DisassembleKitView(kitId: kitId) {
                Task {
                    await viewModel.refresh()
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
            await viewModel.loadData()
        }
    }

    private var availabilityIcon: String {
        if viewModel.availableQuantity == 0 {
            return "xmark.circle.fill"
        } else if viewModel.availableQuantity < 5 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var availabilityColor: Color {
        if viewModel.availableQuantity == 0 {
            return .red
        } else if viewModel.availableQuantity < 5 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Part Row

struct PartRow: View {
    let partWithItem: KitService.PartWithItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(partWithItem.item.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(partWithItem.item.sku)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let category = partWithItem.item.category {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Text("×\(partWithItem.part.quantity)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ViewModel

@MainActor
class KitDetailViewModel: ObservableObject {
    private let kitId: Int64
    private let kitService = KitService()
    private let inventoryLogic = InventoryLogic()

    @Published var kitWithParts: KitService.KitWithParts?
    @Published var availableQuantity: Int = 0
    @Published var shortages: [InventoryLogic.ShortageInfo] = []
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?

    init(kitId: Int64) {
        self.kitId = kitId
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            kitWithParts = try await kitService.fetchKitWithParts(kitId)
            availableQuantity = try await inventoryLogic.calculateAvailableKits(for: kitId)
            shortages = try await inventoryLogic.calculateShortages(for: kitId, quantity: 1)
        } catch {
            errorMessage = "Failed to load kit: \(error.localizedDescription)"
            showError = true
        }
    }

    func refresh() async {
        await loadData()
    }
}

// MARK: - Assemble Kit View

struct AssembleKitView: View {
    let kitId: Int64
    let availableQuantity: Int
    let onComplete: () -> Void

    @StateObject private var viewModel: AssembleKitViewModel
    @Environment(\.dismiss) private var dismiss

    init(kitId: Int64, availableQuantity: Int, onComplete: @escaping () -> Void) {
        self.kitId = kitId
        self.availableQuantity = availableQuantity
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: AssembleKitViewModel(kitId: kitId, maxQuantity: availableQuantity))
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Stepper(
                        "Quantity: \(viewModel.quantity)",
                        value: $viewModel.quantity,
                        in: 1...availableQuantity
                    )

                    HStack {
                        Button("1") { viewModel.quantity = min(1, availableQuantity) }
                        Button("5") { viewModel.quantity = min(5, availableQuantity) }
                        Button("10") { viewModel.quantity = min(10, availableQuantity) }
                        Button("Max") { viewModel.quantity = availableQuantity }
                    }
                    .buttonStyle(.bordered)
                } header: {
                    Text("Assembly Quantity")
                } footer: {
                    Text("Maximum available: \(availableQuantity)")
                }

                Section {
                    Text("This will deduct the required parts from your inventory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Assemble Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assemble") {
                        Task {
                            await viewModel.assemble()
                            onComplete()
                            dismiss()
                        }
                    }
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
    }
}

@MainActor
class AssembleKitViewModel: ObservableObject {
    private let kitId: Int64
    private let inventoryLogic = InventoryLogic()

    @Published var quantity: Int = 1
    @Published var showError = false
    @Published var errorMessage: String?

    init(kitId: Int64, maxQuantity: Int) {
        self.kitId = kitId
        self.quantity = min(1, maxQuantity)
    }

    func assemble() async {
        do {
            try await inventoryLogic.assembleKit(kitId, quantity: quantity)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Disassemble Kit View

struct DisassembleKitView: View {
    let kitId: Int64
    let onComplete: () -> Void

    @StateObject private var viewModel: DisassembleKitViewModel
    @Environment(\.dismiss) private var dismiss

    init(kitId: Int64, onComplete: @escaping () -> Void) {
        self.kitId = kitId
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: DisassembleKitViewModel(kitId: kitId))
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Stepper(
                        "Quantity: \(viewModel.quantity)",
                        value: $viewModel.quantity,
                        in: 1...999
                    )

                    HStack {
                        Button("1") { viewModel.quantity = 1 }
                        Button("5") { viewModel.quantity = 5 }
                        Button("10") { viewModel.quantity = 10 }
                        Button("50") { viewModel.quantity = 50 }
                    }
                    .buttonStyle(.bordered)
                } header: {
                    Text("Disassembly Quantity")
                }

                Section {
                    Text("This will add the kit parts back to your inventory.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Disassemble Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Disassemble") {
                        Task {
                            await viewModel.disassemble()
                            onComplete()
                            dismiss()
                        }
                    }
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
    }
}

@MainActor
class DisassembleKitViewModel: ObservableObject {
    private let kitId: Int64
    private let inventoryLogic = InventoryLogic()

    @Published var quantity: Int = 1
    @Published var showError = false
    @Published var errorMessage: String?

    init(kitId: Int64) {
        self.kitId = kitId
    }

    func disassemble() async {
        do {
            try await inventoryLogic.disassembleKit(kitId, quantity: quantity)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Preview

struct KitDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            KitDetailView(kitId: 1)
        }
    }
}
