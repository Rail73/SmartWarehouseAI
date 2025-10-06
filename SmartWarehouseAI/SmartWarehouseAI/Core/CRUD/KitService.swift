//
//  KitService.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import GRDB

class KitService {
    private let dbManager = DatabaseManager.shared

    // MARK: - Kit CRUD

    func create(_ kit: Kit) async throws -> Kit {
        var mutableKit = kit
        mutableKit.createdAt = Date()
        mutableKit.updatedAt = Date()

        try await dbManager.getDatabase()?.write { db in
            try mutableKit.insert(db)
        }

        return mutableKit
    }

    func fetch(by id: Int64) async throws -> Kit? {
        guard let db = dbManager.getDatabase() else { return nil }

        return try await db.read { db in
            try Kit.fetchOne(db, key: id)
        }
    }

    func fetchBySKU(_ sku: String) async throws -> Kit? {
        guard let db = dbManager.getDatabase() else { return nil }

        return try await db.read { db in
            try Kit
                .filter(Column("sku") == sku)
                .fetchOne(db)
        }
    }

    func fetchAll() async throws -> [Kit] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            try Kit
                .order(Column("name").asc)
                .fetchAll(db)
        }
    }

    func search(query: String) async throws -> [Kit] {
        guard let db = dbManager.getDatabase() else { return [] }

        let pattern = "%\(query)%"

        return try await db.read { db in
            try Kit
                .filter(
                    Column("name").like(pattern) ||
                    Column("sku").like(pattern) ||
                    Column("kitDescription").like(pattern)
                )
                .order(Column("name").asc)
                .fetchAll(db)
        }
    }

    func count() async throws -> Int {
        guard let db = dbManager.getDatabase() else { return 0 }

        return try await db.read { db in
            try Kit.fetchCount(db)
        }
    }

    func update(_ kit: Kit) async throws {
        var mutableKit = kit
        mutableKit.updatedAt = Date()

        try await dbManager.getDatabase()?.write { db in
            try mutableKit.update(db)
        }
    }

    func delete(_ kit: Kit) async throws {
        try await dbManager.getDatabase()?.write { db in
            try kit.delete(db)
        }
    }

    func deleteById(_ id: Int64) async throws {
        try await dbManager.getDatabase()?.write { db in
            try Kit.deleteOne(db, key: id)
        }
    }

    // MARK: - Parts Management

    func addPart(kitId: Int64, itemId: Int64, quantity: Int) async throws -> Part {
        var part = Part(
            kitId: kitId,
            itemId: itemId,
            quantity: quantity
        )

        try await dbManager.getDatabase()?.write { db in
            try part.insert(db)
        }

        return part
    }

    func fetchParts(for kitId: Int64) async throws -> [Part] {
        guard let db = dbManager.getDatabase() else { return [] }

        return try await db.read { db in
            try Part
                .filter(Column("kitId") == kitId)
                .fetchAll(db)
        }
    }

    func updatePart(_ part: Part) async throws {
        try await dbManager.getDatabase()?.write { db in
            try part.update(db)
        }
    }

    func deletePart(_ part: Part) async throws {
        try await dbManager.getDatabase()?.write { db in
            try part.delete(db)
        }
    }

    func deletePartById(_ id: Int64) async throws {
        try await dbManager.getDatabase()?.write { db in
            try Part.deleteOne(db, key: id)
        }
    }

    func deleteAllParts(for kitId: Int64) async throws {
        try await dbManager.getDatabase()?.write { db in
            try Part
                .filter(Column("kitId") == kitId)
                .deleteAll(db)
        }
    }

    // MARK: - Kit with Parts

    struct KitWithParts {
        let kit: Kit
        let parts: [PartWithItem]
    }

    struct PartWithItem {
        let part: Part
        let item: Item
    }

    func fetchKitWithParts(_ kitId: Int64) async throws -> KitWithParts? {
        guard let db = dbManager.getDatabase() else { return nil }

        return try await db.read { db in
            guard let kit = try Kit.fetchOne(db, key: kitId) else {
                return nil
            }

            let parts = try Part
                .filter(Column("kitId") == kitId)
                .fetchAll(db)

            var partsWithItems: [PartWithItem] = []

            for part in parts {
                if let item = try Item.fetchOne(db, key: part.itemId) {
                    partsWithItems.append(PartWithItem(part: part, item: item))
                }
            }

            return KitWithParts(kit: kit, parts: partsWithItems)
        }
    }
}
