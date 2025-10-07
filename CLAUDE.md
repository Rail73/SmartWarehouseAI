# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**SmartWarehouseAI** is a native iOS warehouse management app built with SwiftUI and GRDB.swift. The app manages inventory items, warehouse locations, stock levels, and kit assemblies with QR/barcode scanning capabilities.

## Build & Run Commands

### Building the Project
```bash
# Build for simulator
xcodebuild -project SmartWarehouseAI/SmartWarehouseAI.xcodeproj \
           -scheme SmartWarehouseAI \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           build

# Clean build (use when schema changes occur)
xcodebuild -project SmartWarehouseAI/SmartWarehouseAI.xcodeproj \
           -scheme SmartWarehouseAI \
           clean
```

### Running in Simulator
```bash
# Boot simulator
xcrun simctl boot <DEVICE_UUID>

# Install app
xcrun simctl install <DEVICE_UUID> \
  /Users/rn/Library/Developer/Xcode/DerivedData/SmartWarehouseAI-*/Build/Products/Debug-iphonesimulator/SmartWarehouseAI.app

# Launch app
xcrun simctl launch <DEVICE_UUID> com.smartwarehouse.ai

# View logs (errors only)
xcrun simctl spawn <DEVICE_UUID> log show \
  --predicate 'process == "SmartWarehouseAI" AND (messageType == 16 OR messageType == 17)' \
  --style compact --last 2m
```

### Database Operations
```bash
# Get app container path
xcrun simctl get_app_container <DEVICE_UUID> com.smartwarehouse.ai data

# Access database directly
sqlite3 "<CONTAINER_PATH>/Library/Application Support/warehouse.sqlite"

# Delete database (for fresh schema)
rm -f "<CONTAINER_PATH>/Library/Application Support/warehouse.sqlite"*
```

## Architecture

### Core Data Layer (GRDB)

**DatabaseManager** (`Core/Database/DatabaseManager.swift`) is a singleton that:
- Creates SQLite database at `Application Support/warehouse.sqlite`
- Manages schema creation and migrations
- Uses `ifNotExists: true` for table creation
- **Critical**: Includes migration logic to add `warehouseId` column to existing `stocks` tables

**Migration Pattern**:
```swift
// After creating tables with ifNotExists: true
if try db.tableExists("stocks") {
    let hasWarehouseId = try db.columns(in: "stocks").contains { $0.name == "warehouseId" }
    if !hasWarehouseId {
        try db.alter(table: "stocks") { t in
            t.add(column: "warehouseId", .integer)
        }
    }
}
```

**Database Schema**:
- `items`: Core inventory items (name, SKU, barcode, category)
- `warehouses`: Physical warehouse locations (name, description)
- `stocks`: Item quantities at warehouse locations (itemId → warehouseId foreign key)
- `kits`: Composite products made from items
- `parts`: Kit components (kitId → itemId mapping with quantities)

**Key Relationships**:
- Stock → Item (FOREIGN KEY with CASCADE delete)
- Stock → Warehouse (FOREIGN KEY with SET NULL delete)
- Part → Kit (FOREIGN KEY with CASCADE delete)
- Part → Item (FOREIGN KEY with CASCADE delete)

### Service Layer Pattern

Services (`Core/CRUD/`) follow async/await pattern with GRDB:

```swift
class ItemService {
    private let dbManager = DatabaseManager.shared

    func fetch(_ id: Int64) async throws -> Item? {
        guard let db = dbManager.getDatabase() else { throw ... }
        return try await db.read { db in
            try Item.fetchOne(db, key: id)
        }
    }
}
```

**Service Responsibilities**:
- `ItemService`: Item CRUD operations
- `StockService`: Stock CRUD + `fetchByItem(_ itemId: Int64)` for multi-warehouse view
- `WarehouseService`: Warehouse CRUD + `fetchWarehouseWithItems()` with JOIN queries
- `KitService`: Kit CRUD + assembly/disassembly logic

### QR Code Security Architecture

**QRManager** (`Core/Integrations/QRManager.swift`) implements HMAC-SHA256 signed QR codes:

1. **HMAC Key Management**: 256-bit key stored in Keychain via `KeychainHelper`
2. **URL Scheme**: `swai://item/{id}?sig={base64_hmac}` or `swai://warehouse/{id}?sig={base64_hmac}`
3. **Validation**: All scanned QR codes verified against HMAC before processing

**QRCodeType Enum**:
```swift
enum QRCodeType {
    case item(Int64)
    case warehouse(Int64)
}
```

**Usage Pattern**:
```swift
// Generate QR
if let qrImage = QRManager.shared.generateQRCode(for: .item(42)) {
    // Display in UIImageView
}

// Parse and validate
if let qrType = QRManager.shared.parseQRCode(from: "swai://item/42?sig=...") {
    // Navigation based on type
}
```

### UI Navigation Flow

**TabView Structure** (`ContentView.swift`):
1. Dashboard (tag 0)
2. Items (tag 1) → `ItemDetailView` (shows stock across warehouses)
3. Warehouses (tag 2) → `WarehouseDetailView` (shows items in warehouse)
4. Search (tag 3)
5. Settings (tag 4)

**FloatingScanButton**: Global scanner accessible from any tab, opens `BarcodeScannerView`

**Navigation After Scan**:
- QR codes → Navigate to parent entity detail view (Item or Warehouse)
- Barcodes → Search and display matching item (TODO: implementation pending)

### Model Relationships & Helper Structs

**Stock Model** has two convenience helpers:

1. **StockWithItem** (`Stock.swift`):
   - Combines Stock + Item for inventory views
   - Used in warehouse detail screens

2. **StockWithWarehouse** (`ItemDetailView.swift` ViewModel):
   - Combines Stock + Warehouse for item detail screens
   - Shows where an item is located across warehouses

**GRDB Associations**:
```swift
extension Stock {
    static let item = belongsTo(Item.self)
    static let warehouse = belongsTo(Warehouse.self)
}
```

### Feature Modules

**PDF Import** (`Core/Integrations/`):
- Supports both table-based and OCR-based PDF parsing
- Extracts item/stock data from Excel exports or scanned documents
- Uses ZIPFoundation for archive handling

**Search** (`Core/Search/`):
- `FTS5Search`: Full-text search via SQLite FTS5
- `VectorStore` + `EmbeddingEngine`: Semantic search (future feature)
- `SearchService`: Unified search interface

**Barcode Scanning** (`Core/Integrations/BarcodeScannerManager.swift`):
- AVFoundation-based barcode detection
- Supports all standard barcode formats
- Returns raw barcode string for item lookup

## Development Guidelines

### When Adding New Tables

1. Update `DatabaseManager.createTables()` with new table definition
2. Add migration logic if altering existing tables (check column existence first)
3. Create corresponding GRDB model with `FetchableRecord`, `PersistableRecord`
4. Add CRUD service in `Core/CRUD/`
5. Update indexes section if foreign keys are added

### When Adding New QR Code Types

1. Add case to `QRCodeType` enum in `QRManager.swift`
2. Update `generateQRCode(for:)` switch statement
3. Update `parseQRCode(from:)` regex/parsing logic
4. Add navigation handler in `ContentView.handleScanResult()`
5. Update `BarcodeScannerView` switch cases

### Database Migration Rules

- **Never** remove `ifNotExists: true` from table creation
- **Always** check column existence before `ALTER TABLE`
- Keep deprecated columns (e.g., `location: String?` in Stock) for backward compatibility
- Test migrations with both fresh install and existing database

### Common Pitfalls

1. **Foreign Key References**: Ensure `warehouses` table is created **before** `stocks` table
2. **Index Creation**: Only create indexes **after** all tables and columns exist
3. **Keychain Access**: QRManager requires Keychain entitlements for HMAC key storage
4. **iOS Version Compatibility**: Min deployment target is iOS 15.0, avoid iOS 16+ APIs

## Sprint History

The project has evolved through 7 sprints (see `SPRINT_*_SUMMARY.md` files):
- Sprint 1-3: Foundation (database, models, basic UI)
- Sprint 4: Enhanced inventory UI with CRUD operations
- Sprint 5: Kit management with assembly/disassembly
- Sprint 6: QR/Barcode scanning with HMAC signatures
- Sprint 7: Warehouse management + QR system redesign

## Testing in Simulator

After building, warehouse creation can be tested via:
1. Launch app in simulator
2. Navigate to "Warehouses" tab
3. Tap "+" to create new warehouse
4. Fill name and optional description
5. Save and verify in list

Database can be inspected directly via sqlite3 commands shown above.
