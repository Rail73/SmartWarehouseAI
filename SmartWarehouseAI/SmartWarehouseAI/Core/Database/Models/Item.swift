import Foundation
import GRDB

struct Item: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var name: String
    var sku: String
    var itemDescription: String?
    var category: String?
    var barcode: String?
    var createdAt: Date
    var updatedAt: Date

    static let databaseTableName = "items"

    init(
        id: Int64? = nil,
        name: String,
        sku: String,
        itemDescription: String? = nil,
        category: String? = nil,
        barcode: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sku = sku
        self.itemDescription = itemDescription
        self.category = category
        self.barcode = barcode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Item {
    static let stocks = hasMany(Stock.self)
}
