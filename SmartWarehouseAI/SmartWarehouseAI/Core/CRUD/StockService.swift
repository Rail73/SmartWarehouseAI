//
//  StockService.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import GRDB

class StockService {
    private let dbManager = DatabaseManager.shared

    // MARK: - Create

    func create(_ stock: Stock) async throws -> Stock {
        var mutableStock = stock
        mutableStock.updatedAt = Date()

        try await dbManager.getDatabase()?.write { db in
            try mutableStock.insert(db)
        }

        return mutableStock
    }

    // MARK: - Read

    func fetch(by id: Int64) async throws -> Stock? {
        guard let db = dbManager.getDatabase() else { return nil }

        return try await db.read { db in
            try Stock.fetchOne(db, key: id)
        }
    }

    func fetchByItemId(_ itemId: Int64) async throws -> Stock? {
        guard let db = dbManager.getDatabase() else { return nil }

        return try await db.read { db in
            try Stock
                .filter(Column("itemId") == itemId)
                .fetchOne(db)
        }
    }

    func fetchAll() async throws -> [Stock] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            try Stock.fetchAll(db)
        }
    }

    func fetchByLocation(_ location: String) async throws -> [Stock] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            try Stock
                .filter(Column("location") == location)
                .fetchAll(db)
        }
    }

    func fetchLowStock(threshold: Int? = nil) async throws -> [Stock] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            if let threshold = threshold {
                return try Stock
                    .filter(Column("quantity") <= threshold)
                    .fetchAll(db)
            } else {
                // Use minQuantity from stock record
                return try Stock
                    .filter(Column("minQuantity") != nil)
                    .filter(Column("quantity") <= Column("minQuantity"))
                    .fetchAll(db)
            }
        }
    }

    func totalQuantity() async throws -> Int {
        guard let db = dbManager.getDatabase() else { return 0 }

        return try await db.read { db in
            try Stock
                .select(sum(Column("quantity")), as: Int.self)
                .fetchOne(db) ?? 0
        }
    }

    func count() async throws -> Int {
        guard let db = dbManager.getDatabase() else { return 0 }

        return try await db.read { db in
            try Stock.fetchCount(db)
        }
    }

    // MARK: - Update

    func update(_ stock: Stock) async throws {
        var mutableStock = stock
        mutableStock.updatedAt = Date()

        try await dbManager.getDatabase()?.write { db in
            try mutableStock.update(db)
        }
    }

    func adjustQuantity(itemId: Int64, by delta: Int) async throws {
        guard let db = dbManager.getDatabase() else { return }

        try await db.write { db in
            if var stock = try Stock
                .filter(Column("itemId") == itemId)
                .fetchOne(db) {
                // Update existing stock
                stock.quantity += delta
                stock.updatedAt = Date()
                try stock.update(db)
            } else {
                // Create new stock record
                var newStock = Stock(
                    itemId: itemId,
                    quantity: max(0, delta)
                )
                try newStock.insert(db)
            }
        }
    }

    func setQuantity(itemId: Int64, to quantity: Int) async throws {
        guard let db = dbManager.getDatabase() else { return }

        try await db.write { db in
            if var stock = try Stock
                .filter(Column("itemId") == itemId)
                .fetchOne(db) {
                // Update existing
                stock.quantity = quantity
                stock.updatedAt = Date()
                try stock.update(db)
            } else {
                // Create new
                var newStock = Stock(
                    itemId: itemId,
                    quantity: quantity
                )
                try newStock.insert(db)
            }
        }
    }

    // MARK: - Delete

    func delete(_ stock: Stock) async throws {
        try await dbManager.getDatabase()?.write { db in
            try stock.delete(db)
        }
    }

    func deleteById(_ id: Int64) async throws {
        try await dbManager.getDatabase()?.write { db in
            try Stock.deleteOne(db, key: id)
        }
    }

    func deleteByItemId(_ itemId: Int64) async throws {
        try await dbManager.getDatabase()?.write { db in
            try Stock
                .filter(Column("itemId") == itemId)
                .deleteAll(db)
        }
    }

    // MARK: - Join Queries

    /// Fetch all stocks with their corresponding item details
    func fetchAllWithItems() async throws -> [StockWithItem] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            let request = Stock
                .including(required: Stock.item)
                .order(Column("quantity").asc)

            let rows = try Row.fetchAll(db, request)

            return try rows.map { row in
                let stock = try Stock(row: row)
                let item = try Item(row: row)
                return StockWithItem(stock: stock, item: item)
            }
        }
    }

    /// Fetch stocks with items filtered by location
    func fetchByLocationWithItems(_ location: String) async throws -> [StockWithItem] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            let request = Stock
                .filter(Column("location") == location)
                .including(required: Stock.item)

            let rows = try Row.fetchAll(db, request)

            return try rows.map { row in
                let stock = try Stock(row: row)
                let item = try Item(row: row)
                return StockWithItem(stock: stock, item: item)
            }
        }
    }

    /// Fetch low stock items with details
    func fetchLowStockWithItems(threshold: Int? = nil) async throws -> [StockWithItem] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            let request: QueryInterfaceRequest<Stock>

            if let threshold = threshold {
                request = Stock
                    .filter(Column("quantity") <= threshold)
                    .including(required: Stock.item)
            } else {
                request = Stock
                    .filter(Column("minQuantity") != nil)
                    .filter(Column("quantity") <= Column("minQuantity"))
                    .including(required: Stock.item)
            }

            let rows = try Row.fetchAll(db, request)

            return try rows.map { row in
                let stock = try Stock(row: row)
                let item = try Item(row: row)
                return StockWithItem(stock: stock, item: item)
            }
        }
    }

    /// Get all unique locations
    func fetchLocations() async throws -> [String] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            try Stock
                .select(Column("location"), as: String.self)
                .distinct()
                .filter(Column("location") != nil)
                .order(Column("location").asc)
                .fetchAll(db)
        }
    }
}
