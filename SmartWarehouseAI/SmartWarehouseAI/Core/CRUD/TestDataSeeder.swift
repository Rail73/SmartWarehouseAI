//
//  TestDataSeeder.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation

/// Helper class for seeding test data during development
class TestDataSeeder {
    private let itemService = ItemService()
    private let stockService = StockService()
    private let kitService = KitService()

    /// Seeds sample data for testing
    func seedSampleData() async throws {
        print("🌱 Seeding sample data...")

        // Create sample items
        let items = [
            Item(
                name: "Болт М6x20",
                sku: "BOLT-M6-20",
                itemDescription: "Болт метрический М6, длина 20мм",
                category: "Крепёж"
            ),
            Item(
                name: "Гайка М6",
                sku: "NUT-M6",
                itemDescription: "Гайка метрическая М6",
                category: "Крепёж"
            ),
            Item(
                name: "Шайба М6",
                sku: "WASHER-M6",
                itemDescription: "Шайба плоская М6",
                category: "Крепёж"
            ),
            Item(
                name: "Подшипник 6204",
                sku: "BEARING-6204",
                itemDescription: "Подшипник радиальный 6204",
                category: "Подшипники"
            ),
            Item(
                name: "Винт М4x10",
                sku: "SCREW-M4-10",
                itemDescription: "Винт с потайной головкой М4x10",
                category: "Крепёж"
            )
        ]

        var createdItems: [Item] = []
        for item in items {
            let created = try await itemService.create(item)
            createdItems.append(created)
            print("  ✅ Created item: \(created.name) (SKU: \(created.sku))")
        }

        // Add stock for items
        for item in createdItems {
            guard let itemId = item.id else { continue }

            let quantity = Int.random(in: 50...200)
            let minQty = Int.random(in: 10...30)

            let stock = Stock(
                itemId: itemId,
                quantity: quantity,
                location: "A-\(Int.random(in: 1...10))-\(Int.random(in: 1...5))",
                minQuantity: minQty,
                maxQuantity: minQty * 10
            )

            _ = try await stockService.create(stock)
            print("  📦 Added stock: \(quantity) units at \(stock.location ?? "unknown")")
        }

        // Create a sample kit
        if createdItems.count >= 3 {
            let kit = Kit(
                name: "Комплект крепежа М6",
                kitDescription: "Базовый комплект метизов М6",
                sku: "KIT-M6-BASIC"
            )

            let createdKit = try await kitService.create(kit)
            print("  🎁 Created kit: \(createdKit.name)")

            // Add parts to kit
            if let kitId = createdKit.id {
                // Add bolt
                if let boltId = createdItems[0].id {
                    _ = try await kitService.addPart(kitId: kitId, itemId: boltId, quantity: 10)
                    print("    ➕ Added 10x Болт М6x20")
                }

                // Add nut
                if let nutId = createdItems[1].id {
                    _ = try await kitService.addPart(kitId: kitId, itemId: nutId, quantity: 10)
                    print("    ➕ Added 10x Гайка М6")
                }

                // Add washer
                if let washerId = createdItems[2].id {
                    _ = try await kitService.addPart(kitId: kitId, itemId: washerId, quantity: 20)
                    print("    ➕ Added 20x Шайба М6")
                }
            }
        }

        print("✨ Sample data seeding complete!")
    }

    /// Clears all data from database
    func clearAllData() async throws {
        print("🗑️  Clearing all data...")

        try await itemService.deleteAll()
        print("  ✅ Deleted all items (cascade deletes stocks, kits, parts)")

        print("✨ All data cleared!")
    }

    /// Prints database statistics
    func printStatistics() async throws {
        let itemCount = try await itemService.count()
        let stockCount = try await stockService.count()
        let kitCount = try await kitService.count()
        let totalStock = try await stockService.totalQuantity()

        print("📊 Database Statistics:")
        print("  Items: \(itemCount)")
        print("  Stock records: \(stockCount)")
        print("  Total units in stock: \(totalStock)")
        print("  Kits: \(kitCount)")
    }
}
