import SwiftUI

struct ItemsView: View {
    @State private var items: [Item] = []
    @State private var searchText = ""
    @State private var showingAddItem = false
    @State private var showingPDFImport = false

    var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredItems) { item in
                    ItemRow(item: item)
                }
            }
            .searchable(text: $searchText, prompt: "Search items")
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingPDFImport = true
                    }) {
                        Label("Import PDF", systemImage: "doc.fill.badge.plus")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddItem = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView(isPresented: $showingAddItem, onItemAdded: {
                    loadItems()
                })
            }
            .sheet(isPresented: $showingPDFImport) {
                PDFImportView()
                    .onDisappear {
                        loadItems() // Refresh after import
                    }
            }
            .onAppear {
                loadItems()
            }
        }
    }

    private func loadItems() {
        Task {
            do {
                items = try await ItemService().fetchAll()
            } catch {
                print("Failed to load items: \(error)")
            }
        }
    }
}

struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                if let description = item.itemDescription {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(item.sku)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddItemView: View {
    @Binding var isPresented: Bool
    var onItemAdded: () -> Void
    @State private var name = ""
    @State private var sku = ""
    @State private var description = ""
    @State private var category = ""
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Name", text: $name)
                    TextField("SKU", text: $sku)
                        .autocapitalization(.allCharacters)
                    TextField("Category", text: $category)
                    TextField("Description", text: $description)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            saveItem()
                        }
                        .disabled(name.isEmpty || sku.isEmpty)
                    }
                }
            }
        }
    }

    private func saveItem() {
        isSaving = true

        Task {
            do {
                let newItem = Item(
                    name: name,
                    sku: sku,
                    itemDescription: description.isEmpty ? nil : description,
                    category: category.isEmpty ? nil : category
                )

                _ = try await ItemService().create(newItem)

                await MainActor.run {
                    onItemAdded()
                    isPresented = false
                }
            } catch {
                print("Failed to save item: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

struct ItemsView_Previews: PreviewProvider {
    static var previews: some View {
        ItemsView()
    }
}
