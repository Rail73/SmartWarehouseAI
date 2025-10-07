import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appSettings: AppSettings
    @State private var selectedTab = 0
    @State private var showingScanner = false

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.fill")
                    }
                    .tag(0)

                ItemsView()
                    .tabItem {
                        Label("Items", systemImage: "cube.fill")
                    }
                    .tag(1)

                WarehousesView()
                    .tabItem {
                        Label("Warehouses", systemImage: "building.2.fill")
                    }
                    .tag(2)

                KitsView()
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
                // TODO: Navigate to ItemDetailView
                print("Navigate to Item: \(itemId)")
            case .warehouse(let warehouseId):
                // TODO: Navigate to WarehouseDetailView
                print("Navigate to Warehouse: \(warehouseId)")
            case .kit(let kitId):
                // TODO: Navigate to KitDetailView
                print("Navigate to Kit: \(kitId)")
            }
        } else {
            // Try to find item by barcode
            print("Search item by barcode: \(result)")
            // TODO: Search and navigate to item
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppSettings())
    }
}
