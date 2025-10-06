import SwiftUI

struct DashboardView: View {
    @State private var totalItems: Int = 0
    @State private var lowStockItems: Int = 0
    @State private var totalKits: Int = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    HStack(spacing: 15) {
                        DashboardCard(
                            title: "Total Items",
                            value: "\(totalItems)",
                            icon: "cube.fill",
                            color: .blue
                        )

                        DashboardCard(
                            title: "Low Stock",
                            value: "\(lowStockItems)",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    HStack(spacing: 15) {
                        DashboardCard(
                            title: "Total Kits",
                            value: "\(totalKits)",
                            icon: "shippingbox.fill",
                            color: .green
                        )

                        DashboardCard(
                            title: "Categories",
                            value: "12",
                            icon: "folder.fill",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
            }
            .navigationTitle("Dashboard")
            .onAppear {
                loadDashboardData()
            }
        }
    }

    private func loadDashboardData() {
        Task {
            do {
                let itemService = ItemService()
                let stockService = StockService()
                let kitService = KitService()

                totalItems = try await itemService.count()
                totalKits = try await kitService.count()

                let lowStock = try await stockService.fetchLowStock()
                lowStockItems = lowStock.count
            } catch {
                print("Failed to load dashboard data: \(error)")
            }
        }
    }
}

struct DashboardCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold))

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
