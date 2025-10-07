//
//  WarehouseService.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import Foundation
import GRDB

class WarehouseService {
    private let dbManager = DatabaseManager.shared

    // MARK: - Create

    func create(_ warehouse: Warehouse) async throws -> Warehouse {
        guard let db = dbManager.getDatabase() else {
            throw NSError(domain: "WarehouseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not available"])
        }

        return try await db.write { db in
            var mutableWarehouse = warehouse
            mutableWarehouse.createdAt = Date()
            mutableWarehouse.updatedAt = Date()
            try mutableWarehouse.insert(db)
            return mutableWarehouse
        }
    }

    // MARK: - Read

    func fetch(_ id: Int64) async throws -> Warehouse? {
        guard let db = dbManager.getDatabase() else {
            throw NSError(domain: "WarehouseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not available"])
        }

        return try await db.read { db in
            try Warehouse.fetchOne(db, key: id)
        }
    }

    func fetchAll() async throws -> [Warehouse] {
        guard let db = dbManager.getDatabase() else {
            throw NSError(domain: "WarehouseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not available"])
        }

        return try await db.read { db in
            try Warehouse.order(Column("name")).fetchAll(db)
        }
    }

    // MARK: - Update

    func update(_ warehouse: Warehouse) async throws {
        guard let db = dbManager.getDatabase() else {
            throw NSError(domain: "WarehouseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not available"])
        }

        try await db.write { db in
            var mutableWarehouse = warehouse
            mutableWarehouse.updatedAt = Date()
            try mutableWarehouse.update(db)
        }
    }

    // MARK: - Delete

    func delete(_ id: Int64) async throws {
        guard let db = dbManager.getDatabase() else {
            throw NSError(domain: "WarehouseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not available"])
        }

        _ = try await db.write { db in
            try Warehouse.deleteOne(db, key: id)
        }
    }

    // MARK: - Warehouse with Stock Items

    struct WarehouseWithItems {
        let warehouse: Warehouse
        let stockItems: [StockWithItem]

        var totalItems: Int { stockItems.count }
        var totalQuantity: Int { stockItems.reduce(0) { $0 + $1.quantity } }
        var lowStockCount: Int { stockItems.filter { $0.isLowStock }.count }
        var outOfStockCount: Int { stockItems.filter { $0.isOutOfStock }.count }
    }

    func fetchWarehouseWithItems(_ warehouseId: Int64) async throws -> WarehouseWithItems? {
        guard let db = dbManager.getDatabase() else {
            throw NSError(domain: "WarehouseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Database not available"])
        }

        return try await db.read { db in
            guard let warehouse = try Warehouse.fetchOne(db, key: warehouseId) else {
                return nil
            }

            // Fetch stock items for this warehouse
            let stockItems = try Stock
                .filter(Column("warehouseId") == warehouseId)
                .including(required: Stock.item)
                .asRequest(of: StockWithItemRecord.self)
                .fetchAll(db)
                .map { StockWithItem(stock: $0.stock, item: $0.item) }

            return WarehouseWithItems(warehouse: warehouse, stockItems: stockItems)
        }
    }
}

// MARK: - Helper Record for JOIN

private struct StockWithItemRecord: Decodable, FetchableRecord {
    var stock: Stock
    var item: Item
}
