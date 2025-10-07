import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedTab = 0
    @State private var showingScanner = false
    @State private var navigationTarget: NavigationTarget?

    enum NavigationTarget: Hashable {
        case item(Int64)
        case warehouse(Int64)
        case kit(Int64)
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.fill")
                    }
                    .tag(0)

                ItemsView(navigationTarget: $navigationTarget)
                    .tabItem {
                        Label("Items", systemImage: "cube.fill")
                    }
                    .tag(1)

                WarehousesView(navigationTarget: $navigationTarget)
                    .tabItem {
                        Label("Warehouses", systemImage: "building.2.fill")
                    }
                    .tag(2)

                KitsView(navigationTarget: $navigationTarget)
                    .tabItem {
                        Label("Kits", systemImage: "cube.box.fill")
                    }
                    .tag(3)

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(4)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(5)
            }

            // Floating Scan Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingScanButton {
                        showingScanner = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView { result in
                showingScanner = false
                handleScanResult(result)
            }
        }
    }

    private func handleScanResult(_ result: String) {
        // Try to parse as QR code first
        if let qrData = QRManager.shared.parseQRCode(result) {
            guard qrData.isValid else {
                print("Invalid QR signature")
                return
            }

            // Navigate to appropriate view based on QR type
            switch qrData.type {
            case .item(let itemId):
                navigationTarget = .item(itemId)
                selectedTab = 1 // Items tab
            case .warehouse(let warehouseId):
                navigationTarget = .warehouse(warehouseId)
                selectedTab = 2 // Warehouses tab
            case .kit(let kitId):
                navigationTarget = .kit(kitId)
                selectedTab = 3 // Kits tab
            }
        } else {
            // Try to find item by barcode
            Task {
                await searchItemByBarcode(result)
            }
        }
    }

    private func searchItemByBarcode(_ barcode: String) async {
        let itemService = ItemService()

        do {
            let items = try await itemService.fetchAll()
            if let foundItem = items.first(where: { $0.barcode == barcode }) {
                await MainActor.run {
                    navigationTarget = .item(foundItem.id!)
                    selectedTab = 1 // Items tab
                }
            } else {
                print("No item found with barcode: \(barcode)")
            }
        } catch {
            print("Error searching for item: \(error)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppSettings())
    }
}
