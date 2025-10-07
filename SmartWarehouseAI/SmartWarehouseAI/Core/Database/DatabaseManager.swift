import Foundation
import GRDB

class DatabaseManager {
    static let shared = DatabaseManager()

    private var dbQueue: DatabaseQueue?

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            let databaseURL = appSupportURL.appendingPathComponent("warehouse.sqlite")
            dbQueue = try DatabaseQueue(path: databaseURL.path)

            try createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    private func createTables() throws {
        try dbQueue?.write { db in
            // Create Items table
            try db.create(table: "items", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("sku", .text).notNull().unique()
                t.column("itemDescription", .text)
                t.column("category", .text)
                t.column("barcode", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Create Warehouses table
            try db.create(table: "warehouses", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("warehouseDescription", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Create Stock table
            try db.create(table: "stocks", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("itemId", .integer).notNull()
                    .references("items", onDelete: .cascade)
                t.column("quantity", .integer).notNull()
                t.column("warehouseId", .integer)
                    .references("warehouses", onDelete: .setNull)
                t.column("location", .text) // Deprecated: kept for migration
                t.column("minQuantity", .integer)
                t.column("maxQuantity", .integer)
                t.column("updatedAt", .datetime).notNull()
            }

            // Create Kits table
            try db.create(table: "kits", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("kitDescription", .text)
                t.column("sku", .text).notNull().unique()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // Create Parts table (Kit components)
            try db.create(table: "parts", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("kitId", .integer).notNull()
                    .references("kits", onDelete: .cascade)
                t.column("itemId", .integer).notNull()
                    .references("items", onDelete: .cascade)
                t.column("quantity", .integer).notNull()
                t.column("createdAt", .datetime).notNull()
            }

            // Create indexes
            try db.create(index: "idx_items_sku", on: "items", columns: ["sku"], ifNotExists: true)
            try db.create(index: "idx_stocks_itemId", on: "stocks", columns: ["itemId"], ifNotExists: true)
            try db.create(index: "idx_stocks_warehouseId", on: "stocks", columns: ["warehouseId"], ifNotExists: true)
            try db.create(index: "idx_kits_sku", on: "kits", columns: ["sku"], ifNotExists: true)
            try db.create(index: "idx_parts_kitId", on: "parts", columns: ["kitId"], ifNotExists: true)
            try db.create(index: "idx_parts_itemId", on: "parts", columns: ["itemId"], ifNotExists: true)
        }
    }

    func getDatabase() -> DatabaseQueue? {
        return dbQueue
    }

    // MARK: - Item Operations

    func createItem(_ item: Item) throws {
        try dbQueue?.write { db in
            try item.insert(db)
        }
    }

    func fetchAllItems() throws -> [Item] {
        guard let dbQueue = dbQueue else { return [] }
        return try dbQueue.read { db in
            try Item.fetchAll(db)
        }
    }

    func fetchItem(byId id: Int64) throws -> Item? {
        guard let dbQueue = dbQueue else { return nil }
        return try dbQueue.read { db in
            try Item.fetchOne(db, key: id)
        }
    }

    func updateItem(_ item: Item) throws {
        try dbQueue?.write { db in
            try item.update(db)
        }
    }

    func deleteItem(_ item: Item) throws {
        try dbQueue?.write { db in
            try item.delete(db)
        }
    }

    // MARK: - Stock Operations

    func createStock(_ stock: Stock) throws {
        try dbQueue?.write { db in
            try stock.insert(db)
        }
    }

    func fetchAllStocks() throws -> [Stock] {
        guard let dbQueue = dbQueue else { return [] }
        return try dbQueue.read { db in
            try Stock.fetchAll(db)
        }
    }

    func fetchStock(byItemId itemId: Int64) throws -> Stock? {
        guard let dbQueue = dbQueue else { return nil }
        return try dbQueue.read { db in
            try Stock.filter(Column("itemId") == itemId).fetchOne(db)
        }
    }

    func updateStock(_ stock: Stock) throws {
        try dbQueue?.write { db in
            try stock.update(db)
        }
    }

    func deleteStock(_ stock: Stock) throws {
        try dbQueue?.write { db in
            try stock.delete(db)
        }
    }

    // MARK: - Kit Operations

    func createKit(_ kit: Kit) throws {
        try dbQueue?.write { db in
            try kit.insert(db)
        }
    }

    func fetchAllKits() throws -> [Kit] {
        guard let dbQueue = dbQueue else { return [] }
        return try dbQueue.read { db in
            try Kit.fetchAll(db)
        }
    }

    func fetchKit(byId id: Int64) throws -> Kit? {
        guard let dbQueue = dbQueue else { return nil }
        return try dbQueue.read { db in
            try Kit.fetchOne(db, key: id)
        }
    }

    func updateKit(_ kit: Kit) throws {
        try dbQueue?.write { db in
            try kit.update(db)
        }
    }

    func deleteKit(_ kit: Kit) throws {
        try dbQueue?.write { db in
            try kit.delete(db)
        }
    }

    // MARK: - Part Operations

    func createPart(_ part: Part) throws {
        try dbQueue?.write { db in
            try part.insert(db)
        }
    }

    func fetchParts(forKitId kitId: Int64) throws -> [Part] {
        guard let dbQueue = dbQueue else { return [] }
        return try dbQueue.read { db in
            try Part.filter(Column("kitId") == kitId).fetchAll(db)
        }
    }

    func deletePart(_ part: Part) throws {
        try dbQueue?.write { db in
            try part.delete(db)
        }
    }
}
