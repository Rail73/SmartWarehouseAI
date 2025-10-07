import Foundation
import GRDB

struct Stock: Codable, FetchableRecord, PersistableRecord, Identifiable {
    var id: Int64?
    var itemId: Int64
    var quantity: Int
    var warehouseId: Int64?
    var location: String? // Deprecated: use warehouseId instead, kept for migration
    var minQuantity: Int?
    var maxQuantity: Int?
    var updatedAt: Date

    static let databaseTableName = "stocks"

    init(
        id: Int64? = nil,
        itemId: Int64,
        quantity: Int,
        warehouseId: Int64? = nil,
        location: String? = nil,
        minQuantity: Int? = nil,
        maxQuantity: Int? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.itemId = itemId
        self.quantity = quantity
        self.warehouseId = warehouseId
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
    static let warehouse = belongsTo(Warehouse.self)
}

// MARK: - StockWithItem

/// Combined model for displaying stock with item details
struct StockWithItem: Identifiable {
    let stock: Stock
    let item: Item

    var id: Int64? { stock.id }

    var name: String { item.name }
    var sku: String { item.sku }
    var category: String? { item.category }
    var quantity: Int { stock.quantity }
    var location: String? { stock.location }
    var minQuantity: Int? { stock.minQuantity }
    var maxQuantity: Int? { stock.maxQuantity }
    var updatedAt: Date { stock.updatedAt }

    var isLowStock: Bool {
        guard let minQty = minQuantity else { return false }
        return quantity <= minQty
    }

    var isOutOfStock: Bool {
        return quantity == 0
    }

    var isOverStock: Bool {
        guard let maxQty = maxQuantity else { return false }
        return quantity > maxQty
    }

    var stockStatus: StockStatus {
        if isOutOfStock { return .outOfStock }
        if isLowStock { return .low }
        if isOverStock { return .high }
        return .normal
    }
}

enum StockStatus {
    case outOfStock
    case low
    case normal
    case high

    var color: String {
        switch self {
        case .outOfStock: return "red"
        case .low: return "orange"
        case .normal: return "green"
        case .high: return "blue"
        }
    }

    var icon: String {
        switch self {
        case .outOfStock: return "xmark.circle.fill"
        case .low: return "exclamationmark.triangle.fill"
        case .normal: return "checkmark.circle.fill"
        case .high: return "arrow.up.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .outOfStock: return "Out of Stock"
        case .low: return "Low Stock"
        case .normal: return "Normal"
        case .high: return "Overstock"
        }
    }
}
