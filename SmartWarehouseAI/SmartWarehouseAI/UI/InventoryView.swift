import SwiftUI

struct InventoryView: View {
    @State private var stocks: [Stock] = []
    @State private var searchText = ""

    var filteredStocks: [Stock] {
        if searchText.isEmpty {
            return stocks
        } else {
            return stocks.filter { stock in
                // Filter logic would use item name from database
                true
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredStocks) { stock in
                    StockRow(stock: stock)
                }
            }
            .searchable(text: $searchText, prompt: "Search inventory")
            .navigationTitle("Inventory")
            .onAppear {
                loadStocks()
            }
        }
    }

    private func loadStocks() {
        Task {
            do {
                stocks = try await StockService().fetchAll()
            } catch {
                print("Failed to load stocks: \(error)")
            }
        }
    }
}

struct StockRow: View {
    let stock: Stock

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Item ID: \(stock.itemId)")
                    .font(.headline)
                if let location = stock.location {
                    Text("Location: \(location)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(stock.quantity)")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("units")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InventoryView_Previews: PreviewProvider {
    static var previews: some View {
        InventoryView()
    }
}
