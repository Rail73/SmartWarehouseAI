import Foundation
import GRDB

struct Kit: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var kitDescription: String?
    var sku: String
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "kits"

    init(
        id: Int64? = nil,
        name: String,
        kitDescription: String? = nil,
        sku: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.kitDescription = kitDescription
        self.sku = sku
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Kit {
    static let parts = hasMany(Part.self)
}
