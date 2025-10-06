import Foundation
import GRDB

struct Part: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var kitId: Int64
    var itemId: Int64
    var quantity: Int
    var createdAt: Date

    static let databaseTableName = "parts"

    init(
        id: Int64? = nil,
        kitId: Int64,
        itemId: Int64,
        quantity: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kitId = kitId
        self.itemId = itemId
        self.quantity = quantity
        self.createdAt = createdAt
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Part {
    static let kit = belongsTo(Kit.self)
    static let item = belongsTo(Item.self)
}
