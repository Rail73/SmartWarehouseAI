//
//  InventoryLogic.swift
//  SmartWarehouseAI
//
//  Created on 05.10.2025
//

import Foundation
import GRDB

class InventoryLogic {
    private let stockService = StockService()
    private let kitService = KitService()
    private let itemService = ItemService()
    private let dbManager = DatabaseManager.shared

    // MARK: - Kit Availability

    /// Calculates how many complete kits can be assembled from current stock
    func calculateAvailableKits(for kitId: Int64) async throws -> Int {
        let parts = try await kitService.fetchParts(for: kitId)

        guard !parts.isEmpty else {
            return 0
        }

        var minAvailable = Int.max

        for part in parts {
            guard let stock = try await stockService.fetchByItemId(part.itemId) else {
                return 0 // Missing stock for a required part
            }

            let availableKits = stock.quantity / part.quantity
            minAvailable = min(minAvailable, availableKits)
        }

        return minAvailable == Int.max ? 0 : minAvailable
    }

    /// Checks if a kit can be assembled with given quantity
    func canAssembleKit(_ kitId: Int64, quantity: Int = 1) async throws -> Bool {
        let available = try await calculateAvailableKits(for: kitId)
        return available >= quantity
    }

    // MARK: - Kit Assembly

    enum InventoryError: LocalizedError {
        case invalidQuantity
        case insufficientStock(available: Int, required: Int)
        case kitNotFound(Int64)
        case itemNotFound(Int64)
        case noPartsInKit(Int64)

        var errorDescription: String? {
            switch self {
            case .invalidQuantity:
                return "Quantity must be greater than 0"
            case .insufficientStock(let available, let required):
                return "Insufficient stock. Available: \(available), Required: \(required)"
            case .kitNotFound(let id):
                return "Kit with ID \(id) not found"
            case .itemNotFound(let id):
                return "Item with ID \(id) not found"
            case .noPartsInKit(let id):
                return "Kit \(id) has no parts defined"
            }
        }
    }

    /// Assembles kit(s) by deducting parts from stock
    func assembleKit(_ kitId: Int64, quantity: Int = 1) async throws {
        guard quantity > 0 else {
            throw InventoryError.invalidQuantity
        }

        // Verify kit exists
        guard try await kitService.fetch(by: kitId) != nil else {
            throw InventoryError.kitNotFound(kitId)
        }

        // Check availability
        let available = try await calculateAvailableKits(for: kitId)
        guard available >= quantity else {
            throw InventoryError.insufficientStock(available: available, required: quantity)
        }

        // Get parts
        let parts = try await kitService.fetchParts(for: kitId)
        guard !parts.isEmpty else {
            throw InventoryError.noPartsInKit(kitId)
        }

        // Perform assembly in transaction
        try await dbManager.getDatabase()?.write { db in
            for part in parts {
                guard var stock = try Stock
                    .filter(Column("itemId") == part.itemId)
                    .fetchOne(db) else {
                    throw InventoryError.itemNotFound(part.itemId)
                }

                // Deduct quantity
                stock.quantity -= part.quantity * quantity
                stock.updatedAt = Date()
                try stock.update(db)
            }
        }
    }

    /// Disassembles kit(s) by adding parts back to stock
    func disassembleKit(_ kitId: Int64, quantity: Int = 1) async throws {
        guard quantity > 0 else {
            throw InventoryError.invalidQuantity
        }

        // Verify kit exists
        guard try await kitService.fetch(by: kitId) != nil else {
            throw InventoryError.kitNotFound(kitId)
        }

        // Get parts
        let parts = try await kitService.fetchParts(for: kitId)
        guard !parts.isEmpty else {
            throw InventoryError.noPartsInKit(kitId)
        }

        // Perform disassembly in transaction
        try await dbManager.getDatabase()?.write { db in
            for part in parts {
                if var stock = try Stock
                    .filter(Column("itemId") == part.itemId)
                    .fetchOne(db) {
                    // Update existing stock
                    stock.quantity += part.quantity * quantity
                    stock.updatedAt = Date()
                    try stock.update(db)
                } else {
                    // Create new stock record
                    let newStock = Stock(
                        itemId: part.itemId,
                        quantity: part.quantity * quantity
                    )
                    try newStock.insert(db)
                }
            }
        }
    }

    // MARK: - Stock Analysis

    struct StockAnalysis {
        let totalItems: Int
        let totalStock: Int
        let lowStockItems: Int
        let outOfStockItems: Int
        let overStockItems: Int
    }

    func analyzeStock() async throws -> StockAnalysis {
        let allStocks = try await stockService.fetchAll()

        let totalItems = allStocks.count
        let totalStock = allStocks.reduce(0) { $0 + $1.quantity }

        let lowStock = allStocks.filter { stock in
            if let minQty = stock.minQuantity {
                return stock.quantity <= minQty && stock.quantity > 0
            }
            return false
        }.count

        let outOfStock = allStocks.filter { $0.quantity == 0 }.count

        let overStock = allStocks.filter { stock in
            if let maxQty = stock.maxQuantity {
                return stock.quantity > maxQty
            }
            return false
        }.count

        return StockAnalysis(
            totalItems: totalItems,
            totalStock: totalStock,
            lowStockItems: lowStock,
            outOfStockItems: outOfStock,
            overStockItems: overStock
        )
    }

    // MARK: - Shortage Calculation

    struct ShortageInfo {
        let item: Item
        let required: Int
        let available: Int
        let shortage: Int
    }

    /// Calculates what items are missing to assemble a kit
    func calculateShortages(for kitId: Int64, quantity: Int = 1) async throws -> [ShortageInfo] {
        let parts = try await kitService.fetchParts(for: kitId)
        var shortages: [ShortageInfo] = []

        for part in parts {
            let required = part.quantity * quantity
            let stock = try await stockService.fetchByItemId(part.itemId)
            let available = stock?.quantity ?? 0

            if available < required {
                guard let item = try await itemService.fetch(by: part.itemId) else {
                    continue
                }

                shortages.append(ShortageInfo(
                    item: item,
                    required: required,
                    available: available,
                    shortage: required - available
                ))
            }
        }

        return shortages
    }

    // MARK: - Stock Valuation (если будет добавлена цена)

    func validateStockLevels(for itemId: Int64) async throws -> Bool {
        guard let stock = try await stockService.fetchByItemId(itemId) else {
            return true // No stock record = no violations
        }

        // Check minimum
        if let minQty = stock.minQuantity, stock.quantity < minQty {
            return false
        }

        // Check maximum
        if let maxQty = stock.maxQuantity, stock.quantity > maxQty {
            return false
        }

        return true
    }
}
