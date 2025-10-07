//
//  KitsView.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import SwiftUI

struct KitsView: View {
    @Binding var navigationTarget: ContentView.NavigationTarget?
    @StateObject private var viewModel = KitsViewModel()
    @State private var showingAddKit = false
    @State private var selectedKitId: Int64?
    @State private var isNavigatingToKit = false

    var body: some View {
        NavigationView {
            ZStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading kits...")
                } else if viewModel.kits.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("No Kits")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Create kits to manage multi-item assemblies")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // Summary Section
                        Section {
                            SummaryRow(
                                title: "Total Kits",
                                value: "\(viewModel.kits.count)",
                                icon: "cube.box.fill",
                                color: .blue
                            )
                            SummaryRow(
                                title: "Available",
                                value: "\(viewModel.availableKitsCount)",
                                icon: "checkmark.circle.fill",
                                color: .green
                            )
                            SummaryRow(
                                title: "Low Stock",
                                value: "\(viewModel.lowStockKitsCount)",
                                icon: "exclamationmark.triangle.fill",
                                color: .orange
                            )
                            SummaryRow(
                                title: "Out of Stock",
                                value: "\(viewModel.outOfStockKitsCount)",
                                icon: "xmark.circle.fill",
                                color: .red
                            )
                        } header: {
                            Text("Summary")
                        }

                        // Kits List
                        Section {
                            ForEach(viewModel.filteredKits.filter { $0.kit.id != nil }) { kitInfo in
                                if let kitId = kitInfo.kit.id {
                                    NavigationLink(destination: KitDetailView(kitId: kitId)) {
                                        KitRow(kitInfo: kitInfo)
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text("Kits")
                                Spacer()
                                Text("\(viewModel.filteredKits.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

                // Hidden NavigationLink for programmatic navigation
                NavigationLink(
                    destination: selectedKitId.map { KitDetailView(kitId: $0) },
                    isActive: $isNavigatingToKit
                ) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationTitle("Kits")
            .searchable(text: $viewModel.searchText, prompt: "Search kits...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddKit = true
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
            .sheet(isPresented: $showingAddKit) {
                AddKitView {
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
            .onChange(of: navigationTarget) { target in
                if case .kit(let kitId) = target {
                    selectedKitId = kitId
                    isNavigatingToKit = true
                    navigationTarget = nil
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Kit Row

struct KitRow: View {
    let kitInfo: KitsViewModel.KitInfo

    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title3)

            // Kit Info
            VStack(alignment: .leading, spacing: 4) {
                Text(kitInfo.kit.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(kitInfo.kit.sku)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)
                    Text("\(kitInfo.partsCount) parts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Available Quantity
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(kitInfo.availableQuantity)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor)

                Text("available")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusIcon: String {
        if kitInfo.availableQuantity == 0 {
            return "xmark.circle.fill"
        } else if kitInfo.availableQuantity < 5 {
            return "exclamationmark.triangle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        if kitInfo.availableQuantity == 0 {
            return .red
        } else if kitInfo.availableQuantity < 5 {
            return .orange
        } else {
            return .green
        }
    }
}


// MARK: - ViewModel

@MainActor
class KitsViewModel: ObservableObject {
    @Published var kits: [KitInfo] = []
    @Published var searchText = ""
    @Published var isLoading = false

    private let kitService = KitService()
    private let inventoryLogic = InventoryLogic()

    struct KitInfo: Identifiable {
        let kit: Kit
        let partsCount: Int
        let availableQuantity: Int

        var id: Int64 { kit.id! }
    }

    var filteredKits: [KitInfo] {
        if searchText.isEmpty {
            return kits
        }

        return kits.filter { kitInfo in
            kitInfo.kit.name.localizedCaseInsensitiveContains(searchText) ||
            kitInfo.kit.sku.localizedCaseInsensitiveContains(searchText)
        }
    }

    var availableKitsCount: Int {
        kits.filter { $0.availableQuantity > 0 }.count
    }

    var lowStockKitsCount: Int {
        kits.filter { $0.availableQuantity > 0 && $0.availableQuantity < 5 }.count
    }

    var outOfStockKitsCount: Int {
        kits.filter { $0.availableQuantity == 0 }.count
    }

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allKits = try await kitService.fetchAll()

            var kitInfos: [KitInfo] = []

            for kit in allKits {
                guard let kitId = kit.id else { continue }

                let parts = try await kitService.fetchParts(for: kitId)
                let available = try await inventoryLogic.calculateAvailableKits(for: kitId)

                kitInfos.append(KitInfo(
                    kit: kit,
                    partsCount: parts.count,
                    availableQuantity: available
                ))
            }

            kits = kitInfos
        } catch {
            print("Failed to load kits: \(error)")
        }
    }

    func refresh() async {
        await loadData()
    }
}

// MARK: - Preview

struct KitsView_Previews: PreviewProvider {
    static var previews: some View {
        KitsView(navigationTarget: .constant(nil))
    }
}
