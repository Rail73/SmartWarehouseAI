//
//  Warehouse.swift
//  SmartWarehouseAI
//
//  Created on 06.10.2025
//

import Foundation
import GRDB

struct Warehouse: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var warehouseDescription: String?
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "warehouses"

    init(
        id: Int64? = nil,
        name: String,
        warehouseDescription: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.warehouseDescription = warehouseDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
