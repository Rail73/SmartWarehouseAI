# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Smart Warehouse AI** is an iOS offline inventory management system with AI-powered semantic search capabilities. It's designed for managing spare parts warehouses with features like catalog management, stock tracking, kit assembly, PDF import, and intelligent search.

**Tech Stack:**
- iOS 15+ / macOS 12+ (Mac Catalyst)
- Swift 5.9+ / SwiftUI
- GRDB.swift 6.29.3 (SQLite ORM)
- ZIPFoundation 0.9.19
- Natural Language Framework (embeddings)

## MCP Tools

This project has access to several MCP (Model Context Protocol) servers:

- **Xcodebuild MCP** - REQUIRED for Xcode project operations
  - Use this for adding files to Xcode project
  - Use this for building and running the project
  - ALWAYS prefer MCP tools over manual pbxproj editing
- **IDE MCP** - For diagnostics and code execution
- **Context7 MCP** - For library documentation

### Using Xcodebuild MCP

**IMPORTANT:** When adding new Swift files to the project:
1. Create the file in the correct directory structure
2. Use Xcodebuild MCP to add the file to the Xcode project
3. The MCP server will handle all .pbxproj modifications safely

**NEVER manually edit project.pbxproj** - always use MCP tools or Xcode GUI.

Example workflow:
```
1. Write file: SmartWarehouseAI/UI/NewView.swift
2. Use Xcodebuild MCP to add file to project
3. Build using Xcodebuild MCP or xcodebuild command
```

## Build Commands

### Building the Project

```bash
# Open in Xcode
cd SmartWarehouseAI
open SmartWarehouseAI.xcodeproj

# Build for iOS Simulator (check available simulators with: xcodebuild -list)
xcodebuild -project SmartWarehouseAI.xcodeproj \
           -scheme SmartWarehouseAI \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           clean build

# Run tests
xcodebuild -project SmartWarehouseAI.xcodeproj \
           -scheme SmartWarehouseAI \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           test
```

**Note:** Simulator names may vary (iPhone 15, iPhone 17, iPad Air, etc.). Use `xcodebuild -list` to see available options.

### Running the App

The app must be run through Xcode or built for a physical device/simulator. There's no command-line run option for iOS apps.

### Adding Files to Xcode Project

**IMPORTANT:** When creating new Swift files, they MUST be added to the Xcode project target to be compiled.

**Recommended Method (Xcode GUI):**
1. Create Swift file in the correct directory
2. Open Xcode: `open SmartWarehouseAI.xcodeproj`
3. Right-click the target folder in Project Navigator → "Add Files to SmartWarehouseAI..."
4. Select files, ensure "Add to targets: SmartWarehouseAI" is checked
5. Ensure "Create groups" is selected, NOT "Copy items if needed"

**Programmatic Method (Ruby + xcodeproj gem):**
```bash
gem install xcodeproj

ruby << 'EOF'
require 'xcodeproj'
project = Xcodeproj::Project.open('SmartWarehouseAI.xcodeproj')
ui_group = project.main_group['SmartWarehouseAI']['UI']
file_ref = ui_group.new_reference('NewFile.swift')
project.targets.first.add_file_references([file_ref])
project.save
EOF
```

**Verification:**
```bash
# Build should succeed without "Cannot find in scope" errors
xcodebuild -project SmartWarehouseAI.xcodeproj \
           -scheme SmartWarehouseAI \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           build 2>&1 | grep -E "(error:|BUILD)"
```

## Architecture

### Core Layers

The project follows a clean architecture pattern with separation of concerns:

1. **App Layer** (`SmartWarehouseAI/App/`)
   - `SmartWarehouseAIApp.swift` - App entry point with environment setup
   - `AppSettings.swift` - UserDefaults wrapper for app configuration

2. **Core Layer** (`SmartWarehouseAI/Core/`)
   - **Database** - GRDB-based persistence layer
   - **CRUD** - Service layer for data operations
   - **Logic** - Business logic (inventory calculations, kit assembly)
   - **Search** - Hybrid search engine (FTS5 + Vector embeddings)
   - **Integrations** - External integrations (PDF parsing, QR, export)
   - **Security** - Keychain management for API keys

3. **UI Layer** (`SmartWarehouseAI/UI/`)
   - SwiftUI views following MVVM pattern
   - Views communicate with Core services via async/await

### Key Architecture Patterns

**Database Access Pattern:**
- All database operations go through `DatabaseManager.shared`
- Services use async/await with GRDB's read/write methods
- NEVER access the database queue directly from UI code
- All write operations must be transactional

**Service Layer Pattern:**
```swift
// ✅ Correct: Use services for CRUD operations
let items = try await ItemService().fetchAll()

// ❌ Wrong: Direct database access from UI
let db = DatabaseManager.shared.getDatabase()
let items = try await db.read { db in try Item.fetchAll(db) }
```

**Search Architecture:**
The search system uses a hybrid approach combining:
- **FTS5Search** - Fast full-text search for exact matches and SKU lookups
- **VectorStore** - Semantic search using NLEmbedding for natural language queries
- **SearchService** - Orchestrates both engines with Reciprocal Rank Fusion (RRF)

Mode selection is automatic:
- Single uppercase words → FTS5 (SKU search)
- Short queries (1-2 words) → FTS5 (keyword search)
- Long queries (3+ words) → Hybrid (semantic + keyword)

### Database Schema

**Tables:**
- `items` - Catalog items (name, sku, itemDescription, category, barcode)
- `stocks` - Inventory levels (itemId, quantity, location, minQuantity, maxQuantity)
- `kits` - Assembly kits (name, sku, kitDescription)
- `parts` - Kit components (kitId, itemId, quantity)
- `items_fts` - FTS5 virtual table for full-text search
- `item_vectors` - Vector embeddings for semantic search (itemId, dimension, vector)

**Critical Indexes:**
- `idx_items_sku` - Fast SKU lookups
- `idx_stocks_itemId` - Stock queries by item
- `idx_parts_kitId`, `idx_parts_itemId` - Kit assembly queries

### Transaction Guidelines

**Kit Assembly Example:**
Kit assembly operations MUST be transactional to prevent partial updates:

```swift
// ✅ Correct: Single transaction
try await dbManager.getDatabase()?.write { db in
    let parts = try Part.filter(Column("kitId") == kitId).fetchAll(db)
    for part in parts {
        var stock = try Stock.filter(Column("itemId") == part.itemId).fetchOne(db)
        stock.quantity -= part.quantity * kitQuantity
        try stock.update(db)
    }
}

// ❌ Wrong: Separate write operations (can fail partially)
let parts = try await fetchParts(kitId)
for part in parts {
    try await updateStock(part.itemId, -part.quantity)
}
```

### Error Handling

Use domain-specific error types with `LocalizedError`:

```swift
enum InventoryError: LocalizedError {
    case insufficientStock(available: Int, required: Int)
    case itemNotFound(Int64)

    var errorDescription: String? {
        switch self {
        case .insufficientStock(let available, let required):
            return "Недостаточно запчастей. Доступно: \(available), требуется: \(required)"
        case .itemNotFound(let id):
            return "Позиция #\(id) не найдена"
        }
    }
}
```

## Important Conventions

### Async/Await

All database operations use async/await (not Combine):
```swift
// ✅ Correct
func fetchItems() async throws -> [Item] {
    try await itemService.fetchAll()
}

// ❌ Wrong: Don't mix Combine with GRDB async
func fetchItems() -> AnyPublisher<[Item], Error> {
    Future { promise in
        Task {
            let items = try await self.itemService.fetchAll()
            promise(.success(items))
        }
    }.eraseToAnyPublisher()
}
```

### ViewModels

ViewModels must be `@MainActor` to safely update UI:
```swift
@MainActor
class SearchViewModel: ObservableObject {
    @Published var results: [SearchResult] = []

    func search(_ query: String) async {
        do {
            results = try await searchService.search(query: query)
        } catch {
            print("Search error: \(error)")
        }
    }
}
```

### Date Handling

Always set `createdAt` and `updatedAt` in services, not in UI:
```swift
// ✅ Correct: Service handles timestamps
func create(_ item: Item) async throws -> Item {
    var mutableItem = item
    mutableItem.createdAt = Date()
    mutableItem.updatedAt = Date()
    try await db.write { try mutableItem.insert($0) }
    return mutableItem
}
```

### Column Names

Database column names use camelCase to avoid Swift reserved keywords:
- ✅ `itemDescription` (not `description`)
- ✅ `kitDescription` (not `description`)

### PDF Import Strategy Pattern

The PDF parser uses Strategy Pattern to handle different PDF formats:
```swift
// PDFParserFactory selects the right parser
let parser = PDFParserFactory.parser(for: document)
let items = try await parser.parse(document)

// Strategies:
// - TableBasedPDFParser: Structured PDFs with text tables
// - OCRBasedPDFParser: Scanned PDFs using Vision Framework
```

## Development Workflow

### Sprint Progress

The project is organized in sprints (see `final_project_plan.md`):
- ✅ Sprint 1: Database & CRUD (completed)
- ✅ Sprint 2: PDF Import (completed)
- ✅ Sprint 3: Search (FTS5 + Vector) (completed)
- 🔜 Sprint 4: Inventory UI enhancements
- 🔜 Sprint 5: Kit assembly logic
- 🔜 Sprint 6-10: QR, Export, AI integration, Testing

### Adding New Features

When adding features:
1. Create service in `Core/CRUD/` or appropriate Core subfolder
2. Add business logic to `Core/Logic/` if needed
3. Create UI in `UI/` folder following MVVM pattern
4. Update database migrations in `DatabaseManager` if schema changes
5. Update search indexes if adding searchable fields

### Search Index Updates

When modifying Item fields that should be searchable:
1. FTS5 index updates automatically via triggers
2. Vector embeddings need manual reindexing: `try await vectorStore.updateItemVector(item)`
3. Consider reindexing all items after schema changes: `try await searchService.indexAll()`

## Testing Strategy

### Unit Testing Approach

Test services independently using in-memory database:
```swift
class ItemServiceTests: XCTestCase {
    var testDB: DatabaseQueue!

    override func setUp() async throws {
        // Use in-memory database for tests
        testDB = DatabaseQueue()
        // Run migrations
        try await DatabaseManager.setupTables(in: testDB)
    }
}
```

### Performance Expectations

- Search queries: < 100ms for 10k items
- PDF import: ~1-5 seconds per page depending on complexity
- Vector indexing: ~100-500ms per item
- Kit assembly: < 50ms for 10-component kits

## Critical Risks & Mitigations

### PDF Parsing
**Risk:** Unpredictable PDF formats from various suppliers
**Mitigation:**
- Strategy pattern allows adding format-specific parsers
- Always validate imported data before committing
- Provide manual correction UI after import

### Search Quality
**Risk:** Poor semantic search results
**Mitigation:**
- Hybrid search combines keyword + semantic
- FTS5 handles exact matches reliably
- RRF fusion balances both approaches

### Kit Assembly Data Integrity
**Risk:** Partial stock updates on failure
**Mitigation:**
- All kit operations in single GRDB transaction
- Explicit error types for insufficient stock
- Pre-flight validation before assembly

## Dependencies

Managed via Swift Package Manager:
- **GRDB.swift 6.29.3** - SQLite ORM with migrations
- **ZIPFoundation 0.9.19** - Export/backup functionality

Built-in frameworks:
- Natural Language - Text embeddings (offline)
- Vision - PDF OCR
- AVFoundation - QR scanning (future)
- CoreImage - QR generation (future)

## File Locations Reference

**Database:** `~/Library/Application Support/warehouse.sqlite`
**Keychain Service:** `com.smartwarehouse.ai`

## Code Style

Follow Swift API Design Guidelines:
- Services use async/await (not callbacks)
- Use guard-let for optional unwrapping
- Prefer structs for models, classes for services
- @MainActor for ViewModels
- Explicit error types over generic errors

## Future Development Notes

**v1.4+ Planned Features:**
- QR code generation/scanning with HMAC signatures
- ZIP export with images
- OpenAI integration (optional, with local fallback)
- iCloud sync
- Local LLM (Llama.cpp) instead of OpenAI

When implementing these, maintain the offline-first architecture - all features should work without network connectivity except optional AI.
