import Foundation
import GRDB

struct Stock: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var itemId: Int64
    var quantity: Int
    var location: String?
    var minQuantity: Int?
    var maxQuantity: Int?
    var updatedAt: Date

    static let databaseTableName = "stocks"

    init(
        id: Int64? = nil,
        itemId: Int64,
        quantity: Int,
        location: String? = nil,
        minQuantity: Int? = nil,
        maxQuantity: Int? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.itemId = itemId
        self.quantity = quantity
        self.location = location
        self.minQuantity = minQuantity
        self.maxQuantity = maxQuantity
        self.updatedAt = updatedAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    var isLowStock: Bool {
        guard let minQuantity = minQuantity else { return false }
        return quantity <= minQuantity
    }
}

extension Stock {
    static let item = belongsTo(Item.self)
}
