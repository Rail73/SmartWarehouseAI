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
}
