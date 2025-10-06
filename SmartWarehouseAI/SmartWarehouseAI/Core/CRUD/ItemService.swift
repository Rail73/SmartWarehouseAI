//
//  ItemService.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import GRDB

class ItemService {
    private let dbManager = DatabaseManager.shared

    // MARK: - Create

    func create(_ item: Item) async throws -> Item {
        var mutableItem = item
        mutableItem.createdAt = Date()
        mutableItem.updatedAt = Date()

        try await dbManager.getDatabase()?.write { db in
            try mutableItem.insert(db)
        }

        return mutableItem
    }

    // MARK: - Read

    func fetch(by id: Int64) async throws -> Item? {
        guard let db = dbManager.getDatabase() else { return nil }

        return try await db.read { db in
            try Item.fetchOne(db, key: id)
        }
    }

    func fetchAll() async throws -> [Item] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            try Item
                .order(Column("name").asc)
                .fetchAll(db)
        }
    }

    func fetchByCategory(_ category: String) async throws -> [Item] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            try Item
                .filter(Column("category") == category)
                .order(Column("name").asc)
                .fetchAll(db)
        }
    }

    func fetchBySKU(_ sku: String) async throws -> Item? {
        guard let db = dbManager.getDatabase() else { return nil }

        return try await db.read { db in
            try Item
                .filter(Column("sku") == sku)
                .fetchOne(db)
        }
    }

    func search(query: String) async throws -> [Item] {
        guard let db = dbManager.getDatabase() else { return [] }

        let pattern = "%\(query)%"

        return try await db.read { db in
            try Item
                .filter(
                    Column("name").like(pattern) ||
                    Column("sku").like(pattern) ||
                    Column("itemDescription").like(pattern)
                )
                .order(Column("name").asc)
                .fetchAll(db)
        }
    }

    func count() async throws -> Int {
        guard let db = dbManager.getDatabase() else { return 0 }

        return try await db.read { db in
            try Item.fetchCount(db)
        }
    }

    func categoriesCount() async throws -> Int {
        guard let db = dbManager.getDatabase() else { return 0 }

        return try await db.read { db in
            try Item
                .select(Column("category"), as: String.self)
                .distinct()
                .filter(Column("category") != nil)
                .fetchCount(db)
        }
    }

    func fetchCategories() async throws -> [String] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            try Item
                .select(Column("category"), as: String.self)
                .distinct()
                .filter(Column("category") != nil)
                .order(Column("category").asc)
                .fetchAll(db)
        }
    }

    // MARK: - Update

    func update(_ item: Item) async throws {
        var mutableItem = item
        mutableItem.updatedAt = Date()

        try await dbManager.getDatabase()?.write { db in
            try mutableItem.update(db)
        }
    }

    // MARK: - Delete

    func delete(_ item: Item) async throws {
        try await dbManager.getDatabase()?.write { db in
            try item.delete(db)
        }
    }

    func deleteById(_ id: Int64) async throws {
        try await dbManager.getDatabase()?.write { db in
            try Item.deleteOne(db, key: id)
        }
    }

    func deleteAll() async throws {
        try await dbManager.getDatabase()?.write { db in
            try Item.deleteAll(db)
        }
    }
}
