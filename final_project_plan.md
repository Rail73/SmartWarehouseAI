# 🧭 FINAL PROJECT PLAN v1.2
**Smart Warehouse AI — iOS Application**

---

## 📋 Информация о проекте

| Параметр | Значение |
|----------|----------|
| **Название** | Smart Warehouse AI |
| **Версия** | 1.2 |
| **Платформа** | iOS 15+ / macOS 12+ |
| **Язык** | Swift 5.9+ |
| **UI Framework** | SwiftUI |
| **Дата создания** | 05.10.2025 |
| **Статус** | Ready for Development |
| **Срок разработки** | 15-20 недель (~4-5 месяцев) |

---

## 🎯 Цель проекта

Создать **офлайн-систему учёта и управления складом** с возможностями:

✅ Хранения и поиска запчастей по смыслу  
✅ Ведения остатков и местоположений  
✅ Формирования комплектов  
✅ Импорта каталогов из PDF  
✅ QR-кодирования позиций  
✅ AI-ассистента (опционально, через OpenAI API)  

### Главная идея

> **Это не чат-ассистент, а инструмент для контроля физического склада с умным поиском.**

---

## 🏗️ Архитектура проекта

```
SmartWarehouseAI/
├── App/
│   ├── SmartWarehouseAIApp.swift          # @main entry point
│   └── AppSettings.swift                   # UserDefaults wrapper
│
├── Core/
│   ├── Database/
│   │   ├── DatabaseManager.swift          # GRDB setup + migrations
│   │   └── Models/
│   │       ├── Item.swift                 # Catalog item model
│   │       ├── Stock.swift                # Inventory model
│   │       ├── Kit.swift                  # Assembly kit model
│   │       └── Part.swift                 # Kit component model
│   │
│   ├── CRUD/
│   │   ├── ItemService.swift              # Item CRUD operations
│   │   ├── StockService.swift             # Stock CRUD operations
│   │   └── KitService.swift               # Kit CRUD operations
│   │
│   ├── Logic/
│   │   ├── InventoryLogic.swift           # Stock calculations
│   │   └── AssemblyLogic.swift            # Kit assembly logic
│   │
│   ├── Search/
│   │   ├── FTS5Search.swift               # Full-text search (SQLite)
│   │   ├── EmbeddingEngine.swift          # CoreML embeddings
│   │   ├── VectorStore.swift              # Vector database
│   │   └── RAGEngine.swift                # Context retrieval
│   │
│   ├── Integrations/
│   │   ├── PDFParser.swift                # PDF catalog import
│   │   ├── QRManager.swift                # QR generation/scanning
│   │   ├── ExportService.swift            # ZIP export
│   │   └── LLMService.swift               # OpenAI integration
│   │
│   └── Security/
│       └── KeychainHelper.swift           # Secure key storage
│
├── UI/
│   ├── DashboardView.swift                # Main screen
│   ├── ItemsView.swift                    # Catalog list
│   ├── ItemDetailView.swift               # Item details
│   ├── AddItemView.swift                  # Add/Edit item
│   ├── InventoryView.swift                # Stock management
│   ├── SearchView.swift                   # Smart search
│   └── SettingsView.swift                 # App settings
│
└── Docs/
    ├── ENGINEERING_STANDARDS.md
    ├── README_DEV.md
    ├── PROJECT_PLAN_v1.2.md
    └── FINAL_PROJECT_PLAN_v1.2.md         # Этот файл
```

---

## 🗄️ Модель данных

### Таблица: `items` (Каталог)
```sql
CREATE TABLE items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    code TEXT UNIQUE,
    category TEXT,
    description TEXT,
    image_path TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE VIRTUAL TABLE items_fts USING fts5(name, description, code);
```

### Таблица: `stock` (Остатки)
```sql
CREATE TABLE stock (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL,
    quantity INTEGER DEFAULT 0,
    location TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);
```

### Таблица: `kits` (Комплекты)
```sql
CREATE TABLE kits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    code TEXT UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Таблица: `parts` (Состав комплектов)
```sql
CREATE TABLE parts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kit_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    FOREIGN KEY (kit_id) REFERENCES kits(id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);
```

### Таблица: `item_vectors` (Эмбеддинги)
```sql
CREATE TABLE item_vectors (
    item_id INTEGER PRIMARY KEY,
    dimension INTEGER NOT NULL,
    vector BLOB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE
);
```

---

## 🛠️ Технологический стек

### Основные технологии

| Технология | Назначение | Версия |
|------------|-----------|--------|
| **Swift** | Язык программирования | 5.9+ |
| **SwiftUI** | UI Framework | iOS 15+ |
| **GRDB** | SQLite ORM | 6.x |
| **Combine** | Reactive programming | Built-in |
| **async/await** | Concurrency | Swift 5.5+ |

### Поиск и AI

| Технология | Назначение | Статус |
|------------|-----------|--------|
| **FTS5** | Полнотекстовый поиск | ✅ Встроен в SQLite |
| **CoreML** | Векторные эмбеддинги | ✅ Офлайн |
| **Natural Language** | Токенизация | ✅ Apple Framework |
| **OpenAI API** | LLM ответы | ⚠️ Опционально |

### Интеграции

| Технология | Назначение | Framework |
|------------|-----------|-----------|
| **PDFKit** | Парсинг PDF | Built-in |
| **Vision** | OCR для сканов | Built-in |
| **AVFoundation** | QR сканирование | Built-in |
| **CoreImage** | QR генерация | Built-in |
| **ZIPFoundation** | Архивирование | Third-party |

### Безопасность

| Технология | Назначение | Версия |
|------------|-----------|--------|
| **Keychain** | Хранение API ключей | Built-in |
| **SQLCipher** | Шифрование БД | v2.0 (future) |
| **CryptoKit** | HMAC подписи | Built-in |

---

## 📦 Основные модули

### 1. DatabaseManager
**Ответственность:** Инициализация БД, миграции, транзакции

```swift
class DatabaseManager {
    static let shared = DatabaseManager()
    private var dbQueue: DatabaseQueue!
    
    func setupDatabase() throws {
        var migrator = DatabaseMigrator()
        
        // v1.0 - Initial schema
        migrator.registerMigration("v1.0") { db in
            try db.create(table: "items") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("code", .text).unique()
                t.column("category", .text)
                t.column("description", .text)
                t.column("image_path", .text)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }
            // ... остальные таблицы
        }
        
        // v1.1 - FTS5 index
        migrator.registerMigration("v1.1") { db in
            try db.create(virtualTable: "items_fts", using: FTS5()) { t in
                t.column("name")
                t.column("description")
                t.column("code")
            }
        }
        
        // v1.2 - Vector embeddings
        migrator.registerMigration("v1.2") { db in
            try db.create(table: "item_vectors") { t in
                t.column("item_id", .integer).primaryKey()
                t.column("dimension", .integer).notNull()
                t.column("vector", .blob).notNull()
                t.column("created_at", .datetime).notNull()
            }
        }
        
        try migrator.migrate(dbQueue)
    }
    
    func write<T>(_ updates: (Database) throws -> T) async throws -> T {
        try await dbQueue.write(updates)
    }
    
    func read<T>(_ value: (Database) throws -> T) async throws -> T {
        try await dbQueue.read(value)
    }
}
```

**Критично:** Все операции записи должны быть в транзакциях.

---

### 2. CRUD Services

#### ItemService
```swift
class ItemService {
    private let db = DatabaseManager.shared
    
    func create(_ item: Item) async throws -> Item {
        try await db.write { db in
            var mutableItem = item
            try mutableItem.insert(db)
            return mutableItem
        }
    }
    
    func fetch(_ id: Int) async throws -> Item? {
        try await db.read { db in
            try Item.fetchOne(db, key: id)
        }
    }
    
    func fetchAll(category: String? = nil) async throws -> [Item] {
        try await db.read { db in
            var request = Item.all()
            if let category = category {
                request = request.filter(Column("category") == category)
            }
            return try request.fetchAll(db)
        }
    }
    
    func update(_ item: Item) async throws {
        try await db.write { db in
            var mutableItem = item
            mutableItem.updatedAt = Date()
            try mutableItem.update(db)
        }
    }
    
    func delete(_ id: Int) async throws {
        try await db.write { db in
            try Item.deleteOne(db, key: id)
        }
    }
}
```

---

### 3. InventoryLogic
**Ответственность:** Расчёт остатков, доступных комплектов, дефицита

```swift
class InventoryLogic {
    private let stockService = StockService()
    private let kitService = KitService()
    
    // Расчёт доступных комплектов
    func calculateAvailableKits(_ kit: Kit) async throws -> Int {
        let parts = try await kitService.fetchParts(kitId: kit.id)
        var minKits = Int.max
        
        for part in parts {
            guard let stock = try await stockService.fetch(itemId: part.itemId) else {
                return 0
            }
            let availableKits = stock.quantity / part.quantity
            minKits = min(minKits, availableKits)
        }
        
        return minKits == Int.max ? 0 : minKits
    }
    
    // Сборка комплекта (с транзакцией)
    func assembleKit(_ kit: Kit, quantity: Int = 1) async throws {
        guard quantity > 0 else {
            throw InventoryError.invalidQuantity
        }
        
        let available = try await calculateAvailableKits(kit)
        guard available >= quantity else {
            throw InventoryError.insufficientStock(available: available, required: quantity)
        }
        
        try await DatabaseManager.shared.write { db in
            let parts = try Part
                .filter(Column("kit_id") == kit.id)
                .fetchAll(db)
            
            for part in parts {
                guard var stock = try Stock
                    .filter(Column("item_id") == part.itemId)
                    .fetchOne(db) else {
                    throw InventoryError.itemNotFound(part.itemId)
                }
                
                stock.quantity -= part.quantity * quantity
                stock.updatedAt = Date()
                try stock.update(db)
            }
            
            // Логирование операции
            var log = AssemblyLog(
                kitId: kit.id,
                quantity: quantity,
                timestamp: Date()
            )
            try log.insert(db)
        }
    }
}

enum InventoryError: LocalizedError {
    case invalidQuantity
    case insufficientStock(available: Int, required: Int)
    case itemNotFound(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            return "Количество должно быть больше 0"
        case .insufficientStock(let available, let required):
            return "Недостаточно запчастей. Доступно: \(available), требуется: \(required)"
        case .itemNotFound(let id):
            return "Позиция с ID \(id) не найдена на складе"
        }
    }
}
```

---

### 4. Search Layer

#### FTS5Search
```swift
class FTS5Search {
    private let db = DatabaseManager.shared
    
    func search(_ query: String, limit: Int = 50) async throws -> [Item] {
        try await db.read { db in
            let pattern = FTS5Pattern(matchingAllTokensIn: query)
            return try Item
                .matching(pattern)
                .limit(limit)
                .fetchAll(db)
        }
    }
}
```

#### EmbeddingEngine
```swift
import NaturalLanguage
import CoreML

class EmbeddingEngine {
    private var model: MLModel?
    
    init() {
        // Загрузка CoreML модели эмбеддингов
        // Например: sentence-transformers/all-MiniLM-L6-v2
        loadModel()
    }
    
    func embed(_ text: String) async throws -> [Float] {
        // Генерация эмбеддинга через CoreML
        guard let model = model else {
            throw EmbeddingError.modelNotLoaded
        }
        
        // Токенизация
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        let tokens = tokenizer.tokens(for: text.startIndex..<text.endIndex)
        
        // Получение эмбеддинга
        // ... CoreML inference
        
        return [] // vector embedding
    }
    
    private func loadModel() {
        // Загрузка модели из bundle
    }
}
```

#### VectorStore
```swift
class VectorStore {
    private let db = DatabaseManager.shared
    
    func save(vector: [Float], for itemId: Int) async throws {
        let data = Data(bytes: vector, count: vector.count * MemoryLayout<Float>.size)
        
        try await db.write { db in
            var itemVector = ItemVector(
                itemId: itemId,
                dimension: vector.count,
                vector: data
            )
            try itemVector.save(db)
        }
    }
    
    func search(embedding: [Float], limit: Int = 10) async throws -> [(Item, Float)] {
        // Косинусное сходство для поиска ближайших векторов
        let allVectors = try await fetchAllVectors()
        var results: [(Item, Float)] = []
        
        for (item, vector) in allVectors {
            let similarity = cosineSimilarity(embedding, vector)
            results.append((item, similarity))
        }
        
        return results
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0 }
    }
    
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        return dotProduct / (magnitudeA * magnitudeB)
    }
}
```

---

### 5. PDFParser (Strategy Pattern)

```swift
protocol PDFParserStrategy {
    func canParse(_ document: PDFDocument) -> Bool
    func parse(_ document: PDFDocument) async throws -> [Item]
}

// Парсер таблиц
class TableBasedPDFParser: PDFParserStrategy {
    func canParse(_ document: PDFDocument) -> Bool {
        // Проверка наличия таблиц
        return true
    }
    
    func parse(_ document: PDFDocument) async throws -> [Item] {
        var items: [Item] = []
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            // Извлечение текста
            let text = page.string ?? ""
            
            // Парсинг структурированных данных
            // TODO: Реализация извлечения из таблиц
        }
        
        return items
    }
}

// OCR для сканированных PDF
class OCRBasedPDFParser: PDFParserStrategy {
    func canParse(_ document: PDFDocument) -> Bool {
        // Проверка, что PDF это скан
        return true
    }
    
    func parse(_ document: PDFDocument) async throws -> [Item] {
        // Vision Framework для OCR
        var items: [Item] = []
        
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let image = page.thumbnail(of: CGSize(width: 1024, height: 1024), for: .mediaBox) else {
                continue
            }
            
            let text = try await recognizeText(in: image)
            // Парсинг распознанного текста
        }
        
        return items
    }
    
    private func recognizeText(in image: UIImage) async throws -> String {
        // Vision текст recognition
        return ""
    }
}

// Фабрика парсеров
class PDFParserFactory {
    static func parser(for document: PDFDocument) -> PDFParserStrategy {
        if TableBasedPDFParser().canParse(document) {
            return TableBasedPDFParser()
        } else {
            return OCRBasedPDFParser()
        }
    }
}

// Главный сервис
class PDFParser {
    func importCatalog(from url: URL) async throws -> [Item] {
        guard let document = PDFDocument(url: url) else {
            throw PDFError.cannotOpen
        }
        
        let parser = PDFParserFactory.parser(for: document)
        return try await parser.parse(document)
    }
}
```

**⚠️ РИСК:** PDF форматы непредсказуемы. Необходима ручная проверка после импорта.

---

### 6. QRManager

```swift
import CoreImage
import AVFoundation
import CryptoKit

class QRManager {
    // HMAC секрет для подписи
    private let hmacKey: SymmetricKey
    
    init() {
        if let keyData = KeychainHelper.getHMACKey() {
            hmacKey = SymmetricKey(data: keyData)
        } else {
            hmacKey = SymmetricKey(size: .bits256)
            KeychainHelper.saveHMACKey(hmacKey.withUnsafeBytes { Data($0) })
        }
    }
    
    // Генерация QR с подписью
    func generateQR(for item: Item) throws -> UIImage {
        let payload = QRPayload(
            itemId: item.id,
            code: item.code ?? "",
            name: item.name,
            timestamp: Date().timeIntervalSince1970,
            signature: sign(itemId: item.id, code: item.code ?? "")
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(payload)
        
        return try generateQRImage(from: jsonData)
    }
    
    // Сканирование и валидация QR
    func validateQR(_ data: Data) throws -> Item {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(QRPayload.self, from: data)
        
        // Проверка подписи
        guard verifySignature(payload) else {
            throw QRError.invalidSignature
        }
        
        // Проверка актуальности (не старше 1 года)
        let timestamp = Date(timeIntervalSince1970: payload.timestamp)
        let age = Date().timeIntervalSince(timestamp)
        guard age < 365 * 24 * 3600 else {
            throw QRError.expired
        }
        
        // Загрузка item из БД
        return try await ItemService().fetch(payload.itemId)
    }
    
    private func sign(itemId: Int, code: String) -> String {
        let data = "\(itemId):\(code)".data(using: .utf8)!
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: hmacKey)
        return Data(signature).base64EncodedString()
    }
    
    private func verifySignature(_ payload: QRPayload) -> Bool {
        let expectedSignature = sign(itemId: payload.itemId, code: payload.code)
        return expectedSignature == payload.signature
    }
    
    private func generateQRImage(from data: Data) throws -> UIImage {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw QRError.generationFailed
        }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        
        guard let ciImage = filter.outputImage else {
            throw QRError.generationFailed
        }
        
        // Масштабирование для лучшего качества
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw QRError.generationFailed
        }
        
        return UIImage(cgImage: cgImage)
    }
}

struct QRPayload: Codable {
    let itemId: Int
    let code: String
    let name: String
    let timestamp: TimeInterval
    let signature: String
}

enum QRError: LocalizedError {
    case generationFailed
    case invalidSignature
    case expired
    case itemNotFound
    
    var errorDescription: String? {
        switch self {
        case .generationFailed: return "Не удалось создать QR-код"
        case .invalidSignature: return "QR-код поддельный или повреждён"
        case .expired: return "QR-код устарел"
        case .itemNotFound: return "Позиция не найдена в базе"
        }
    }
}
```

---

### 7. LLMService (с fallback)

```swift
protocol LLMService {
    func query(_ prompt: String, context: [Item]) async throws -> String
}

// OpenAI реализация
class OpenAIService: LLMService {
    private let apiKey: String?
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    
    init() {
        self.apiKey = KeychainHelper.getOpenAIKey()
    }
    
    func query(_ prompt: String, context: [Item]) async throws -> String {
        guard let apiKey = apiKey else {
            throw LLMError.noAPIKey
        }
        
        // Формирование контекста
        let contextText = context.map {
            "[\($0.code ?? "N/A")] \($0.name): \($0.description ?? "")"
        }.joined(separator: "\n")
        
        let messages = [
            ["role": "system", "content": "Ты ассистент для управления складом. Отвечай кратко и по делу."],
            ["role": "user", "content": "Контекст:\n\(contextText)\n\nВопрос: \(prompt)"]
        ]
        
        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.3
        ]
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LLMError.apiError
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        
        return content
    }
}

// Локальный fallback
class LocalSearchService: LLMService {
    func query(_ prompt: String, context: [Item]) async throws -> String {
        guard !context.isEmpty else {
            return "❌ Ничего не найдено по запросу '\(prompt)'"
        }
        
        var result = "📦 Найдено позиций: \(context.count)\n\n"
        
        for (index, item) in context.prefix(5).enumerated() {
            result += "\(index + 1). [\(item.code ?? "—")] \(item.name)\n"
            if let description = item.description, !description.isEmpty {
                result += "   \(description)\n"
            }
            result += "\n"
        }
        
        if context.count > 5 {
            result += "... и ещё \(context.count - 5) позиций"
        }
        
        return result
    }
}

// Главный сервис с автоматическим fallback
class SmartSearchService {
    private let openAI = OpenAIService()
    private let local = LocalSearchService()
    private let useAI: Bool
    
    init(useAI: Bool = true) {
        self.useAI = useAI && KeychainHelper.getOpenAIKey() != nil
    }
    
    func search(_ query: String, context: [Item]) async -> String {
        if useAI {
            do {
                return try await openAI.query(query, context: context)
            } catch {
                print("⚠️ OpenAI недоступен, используем локальный поиск: \(error)")
                return try! await local.query(query, context: context)
            }
        } else {
            return try! await local.query(query, context: context)
        }
    }
}

enum LLMError: LocalizedError {
    case noAPIKey
    case apiError
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "API ключ OpenAI не настроен"
        case .apiError: return "Ошибка API OpenAI"
        case .invalidResponse: return "Некорректный ответ от API"
        }
    }
}
```

---

### 8. KeychainHelper

```swift
import Security
import Foundation

class KeychainHelper {
    private static let service = "com.smartwarehouse.ai"
    
    // OpenAI API Key
    static func saveOpenAIKey(_ key: String) {
        save(key, for: "openai_api_key")
    }
    
    static func getOpenAIKey() -> String? {
        get(for: "openai_api_key")
    }
    
    // HMAC Key для QR подписей
    static func saveHMACKey(_ data: Data) {
        save(data, for: "hmac_key")
    }
    
    static func getHMACKey() -> Data? {
        getData(for: "hmac_key")
    }
    
    // Базовые методы
    private static func save(_ value: String, for account: String) {
        guard let data = value.data(using: .utf8) else { return }
        save(data, for: account)
    }
    
    private static func save(_ data: Data, for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Удаляем старое значение
        SecItemDelete(query as CFDictionary)
        
        // Сохраняем новое
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ Keychain save error: \(status)")
        }
    }
    
    private static func get(for account: String) -> String? {
        guard let data = getData(for: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private static func getData(for account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        return result as? Data
    }
    
    static func delete(for account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
```

---

## 🎨 UI Layer (SwiftUI)

### DashboardView
```swift
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Статистика
                    StatsGrid(stats: viewModel.stats)
                    
                    // Последние действия
                    RecentActivitySection(activities: viewModel.recentActivities)
                    
                    // Низкие остатки
                    LowStockSection(items: viewModel.lowStockItems)
                    
                    // Быстрые действия
                    QuickActionsSection()
                }
                .padding()
            }
            .navigationTitle("📦 Склад")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(destination: SearchView()) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats: WarehouseStats = .empty
    @Published var recentActivities: [Activity] = []
    @Published var lowStockItems: [Item] = []
    
    private let itemService = ItemService()
    private let stockService = StockService()
    
    func loadData() async {
        do {
            async let statsTask = loadStats()
            async let activitiesTask = loadActivities()
            async let lowStockTask = loadLowStock()
            
            stats = try await statsTask
            recentActivities = try await activitiesTask
            lowStockItems = try await lowStockTask
        } catch {
            print("❌ Error loading dashboard: \(error)")
        }
    }
    
    private func loadStats() async throws -> WarehouseStats {
        let totalItems = try await itemService.count()
        let totalStock = try await stockService.totalQuantity()
        let categories = try await itemService.categoriesCount()
        
        return WarehouseStats(
            totalItems: totalItems,
            totalStock: totalStock,
            categories: categories
        )
    }
    
    private func loadActivities() async throws -> [Activity] {
        // Последние изменения
        return []
    }
    
    private func loadLowStock() async throws -> [Item] {
        try await stockService.itemsWithLowStock(threshold: 5)
    }
}
```

### SearchView (Гибридный поиск)
```swift
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @State private var showScanner = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Поисковая строка
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Поиск по названию, коду или описанию", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        Task {
                            await viewModel.search(newValue)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                
                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            // Результаты
            if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.results.isEmpty && !searchText.isEmpty {
                ContentUnavailableView(
                    "Ничего не найдено",
                    systemImage: "magnifyingglass",
                    description: Text("Попробуйте изменить запрос")
                )
            } else {
                List(viewModel.results) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        ItemRow(item: item)
                    }
                }
                .listStyle(.plain)
            }
            
            // AI ответ (если включён)
            if let aiResponse = viewModel.aiResponse {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("AI Ассистент")
                            .font(.headline)
                        Spacer()
                    }
                    
                    Text(aiResponse)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding()
            }
        }
        .navigationTitle("Поиск")
        .sheet(isPresented: $showScanner) {
            QRScannerView { result in
                Task {
                    await viewModel.handleQRScan(result)
                }
            }
        }
    }
}

@MainActor
class SearchViewModel: ObservableObject {
    @Published var results: [Item] = []
    @Published var aiResponse: String?
    @Published var isSearching = false
    
    private let ftsSearch = FTS5Search()
    private let vectorStore = VectorStore()
    private let embeddingEngine = EmbeddingEngine()
    private let llmService = SmartSearchService()
    
    func search(_ query: String) async {
        guard !query.isEmpty else {
            results = []
            aiResponse = nil
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            // Гибридный поиск: FTS5 + Vector
            async let ftsResults = ftsSearch.search(query)
            async let vectorResults = searchByEmbedding(query)
            
            let fts = try await ftsResults
            let vector = try await vectorResults
            
            // Объединение результатов
            results = mergeResults(fts, vector)
            
            // AI ответ (если включён в настройках)
            if AppSettings.shared.useAI {
                aiResponse = await llmService.search(query, context: results)
            }
        } catch {
            print("❌ Search error: \(error)")
        }
    }
    
    private func searchByEmbedding(_ query: String) async throws -> [Item] {
        let embedding = try await embeddingEngine.embed(query)
        let results = try await vectorStore.search(embedding: embedding)
        return results.map { $0.0 }
    }
    
    private func mergeResults(_ fts: [Item], _ vector: [Item]) -> [Item] {
        // Объединяем результаты, убираем дубликаты
        var seen = Set<Int>()
        var merged: [Item] = []
        
        for item in fts + vector {
            if !seen.contains(item.id) {
                seen.insert(item.id)
                merged.append(item)
            }
        }
        
        return merged
    }
    
    func handleQRScan(_ data: Data) async {
        do {
            let item = try await QRManager().validateQR(data)
            results = [item]
        } catch {
            print("❌ QR scan error: \(error)")
        }
    }
}
```

---

## 📊 Roadmap по спринтам

### Спринт 1: База и CRUD (2 недели)
**Цель:** Создать фундамент приложения

✅ **Задачи:**
1. Инициализация Xcode проекта
2. Настройка GRDB + миграции
3. Создание моделей (Item, Stock, Kit, Part)
4. Реализация CRUD сервисов
5. Unit тесты для бизнес-логики

**Результат:** Работающая БД с базовыми операциями

---

### Спринт 2: Импорт PDF (2-3 недели)
**Цель:** Реализовать импорт каталогов

⚠️ **КРИТИЧНЫЙ СПРИНТ**

✅ **Задачи:**
1. PDFParser с Strategy Pattern
2. TableBasedPDFParser
3. OCRBasedPDFParser (Vision Framework)
4. UI для импорта и валидации
5. Тестирование на 5+ разных форматах PDF

**Результат:** Рабочий импорт с ручной коррекцией

**Риски:** Непредсказуемые форматы PDF  
**Митигация:** Адаптеры + ручная проверка

---

### Спринт 3: Поиск (2 недели)
**Цель:** Реализовать умный поиск

✅ **Задачи:**
1. FTS5Search для текстового поиска
2. EmbeddingEngine (CoreML)
3. VectorStore для семантического поиска
4. Гибридный алгоритм объединения результатов
5. SearchView UI

**Результат:** Офлайн поиск по смыслу

---

### Спринт 4: Остатки (1 неделя)
**Цель:** CRUD для склада

✅ **Задачи:**
1. StockService полный функционал
2. InventoryView UI
3. Отчёт "что есть на складе"
4. Фильтры по местоположению

**Результат:** Управление остатками

---

### Спринт 5: Комплекты (1-2 недели)
**Цель:** Логика сборки

✅ **Задачи:**
1. KitService + AssemblyLogic
2. Расчёт доступных комплектов
3. Транзакционная сборка
4. UI для создания комплектов
5. Проверка дефицита

**Результат:** MVP готов

---

### Спринт 6: QR-система (1 неделя)
**Цель:** Генерация и сканирование QR

✅ **Задачи:**
1. QRManager с HMAC подписью
2. Генерация QR для items
3. AVFoundation сканер
4. Валидация подлинности

**Результат:** QR-маркировка склада

---

### Спринт 7: Экспорт (1 неделя)
**Цель:** Резервное копирование

✅ **Задачи:**
1. ExportService
2. Архивирование БД + изображений в .zip
3. Расшаривание через Share Sheet

**Результат:** Бэкап системы

---

### Спринт 8: UI-финализация (1-2 недели)
**Цель:** Полировка интерфейса

✅ **Задачи:**
1. DashboardView с статистикой
2. Фильтры и сортировка
3. Dark Mode поддержка
4. Анимации и transitions
5. Accessibility

**Результат:** Production-ready UI

---

### Спринт 9: OpenAI (1 неделя)
**Цель:** AI-ассистент

✅ **Задачи:**
1. LLMService интерфейс
2. OpenAIService реализация
3. LocalSearchService fallback
4. Настройка API ключа в Settings
5. Обработка ошибок

**Результат:** Опциональный AI

---

### Спринт 10: Beta-сборка (2 недели)
**Цель:** Тестирование и релиз

✅ **Задачи:**
1. Integration тесты
2. UI тесты (XCUITest)
3. Performance profiling (Instruments)
4. Memory leak detection
5. Документация пользователя
6. TestFlight beta

**Результат:** v1.2 Release

---

## 🔍 Критические риски

### 🔴 ВЫСОКИЙ: PDF Parsing
**Проблема:** Нет стандарта для каталогов запчастей

**Решение:**
- Strategy Pattern для разных форматов
- Vision OCR для сканов
- Ручная валидация после импорта
- Адаптеры для популярных форматов

**Время:** +1 неделя на тестирование

---

### 🟡 СРЕДНИЙ: CoreML Embeddings
**Проблема:** Качество семантического поиска

**Решение:**
- Начать с Apple Natural Language
- Опционально: Sentence Transformers
- A/B тестирование качества
- Фоновая индексация

**Альтернатива:** Только FTS5 для MVP

---

### 🟡 СРЕДНИЙ: OpenAI Costs
**Проблема:** Стоимость API запросов

**Решение:**
- AI опционален (настройка в Settings)
- Автоматический fallback на локальный поиск
- Кэширование ответов
- Rate limiting (1 запрос/секунда)

---

### 🟢 НИЗКИЙ: Performance
**Проблема:** Медленная работа с большими каталогами

**Решение:**
- Lazy loading для списков
- Пагинация (50 items/page)
- Background indexing для векторов
- GRDB оптимизирован из коробки

---

## 🧪 Тестирование

### Unit Tests
```swift
// DatabaseTests.swift
class DatabaseTests: XCTestCase {
    var db: DatabaseManager!
    
    override func setUp() async throws {
        db = DatabaseManager.test() // In-memory DB
    }
    
    func testItemCRUD() async throws {
        let service = ItemService()
        
        // Create
        var item = Item(name: "Test Item", code: "T001")
        item = try await service.create(item)
        XCTAssertNotNil(item.id)
        
        // Read
        let fetched = try await service.fetch(item.id)
        XCTAssertEqual(fetched?.name, "Test Item")
        
        // Update
        item.name = "Updated"
        try await service.update(item)
        let updated = try await service.fetch(item.id)
        XCTAssertEqual(updated?.name, "Updated")
        
        // Delete
        try await service.delete(item.id)
        let deleted = try await service.fetch(item.id)
        XCTAssertNil(deleted)
    }
}

// InventoryLogicTests.swift
class InventoryLogicTests: XCTestCase {
    func testAssembleKit_Success() async throws {
        // Given
        let item1 = try await ItemService().create(Item(name: "Bolt", code: "B001"))
        let item2 = try await ItemService().create(Item(name: "Nut", code: "N001"))
        
        try await StockService().create(Stock(itemId: item1.id, quantity: 100))
        try await StockService().create(Stock(itemId: item2.id, quantity: 100))
        
        var kit = Kit(name: "Set", code: "S001")
        kit = try await KitService().create(kit)
        
        try await KitService().addPart(kitId: kit.id, itemId: item1.id, quantity: 2)
        try await KitService().addPart(kitId: kit.id, itemId: item2.id, quantity: 2)
        
        let logic = InventoryLogic()
        
        // When
        try await logic.assembleKit(kit, quantity: 10)
        
        // Then
        let stock1 = try await StockService().fetch(itemId: item1.id)
        let stock2 = try await StockService().fetch(itemId: item2.id)
        
        XCTAssertEqual(stock1?.quantity, 80) // 100 - (2 * 10)
        XCTAssertEqual(stock2?.quantity, 80)
    }
    
    func testAssembleKit_InsufficientStock() async throws {
        // Given
        let item = try await ItemService().create(Item(name: "Bolt"))
        try await StockService().create(Stock(itemId: item.id, quantity: 5))
        
        var kit = Kit(name: "Set")
        kit = try await KitService().create(kit)
        try await KitService().addPart(kitId: kit.id, itemId: item.id, quantity: 10)
        
        let logic = InventoryLogic()
        
        // When/Then
        await assertThrowsError(
            try await logic.assembleKit(kit),
            InventoryError.insufficientStock
        )
    }
}
```

### Integration Tests
```swift
class SearchIntegrationTests: XCTestCase {
    func testHybridSearch() async throws {
        // Given
        let items = [
            Item(name: "Болт М6", code: "B006", description: "Крепёжный элемент"),
            Item(name: "Гайка М6", code: "N006", description: "Фиксирующая деталь"),
            Item(name: "Шайба", code: "W001", description: "Прокладка под болт")
        ]
        
        for item in items {
            _ = try await ItemService().create(item)
        }
        
        let viewModel = SearchViewModel()
        
        // When
        await viewModel.search("крепёж")
        
        // Then
        XCTAssertFalse(viewModel.results.isEmpty)
        XCTAssertTrue(viewModel.results.contains { $0.name.contains("Болт") })
    }
}
```

### UI Tests
```swift
class SmartWarehouseUITests: XCTestCase {
    func testAddItem() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Items
        app.tabBars.buttons["Каталог"].tap()
        
        // Add new item
        app.navigationBars.buttons["plus"].tap()
        
        // Fill form
        app.textFields["Название"].tap()
        app.textFields["Название"].typeText("Test Item")
        
        app.textFields["Код"].tap()
        app.textFields["Код"].typeText("T001")
        
        // Save
        app.navigationBars.buttons["Сохранить"].tap()
        
        // Verify
        XCTAssertTrue(app.staticTexts["Test Item"].exists)
    }
}
```

---

## 🚀 Deployment

### Минимальные требования
- iOS 15.0+
- macOS 12.0+ (для Mac Catalyst)
- Xcode 15.0+
- Swift 5.9+

### Зависимости (SPM)
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
]
```

### Build Configuration

**Debug:**
```swift
// Verbose logging
// In-memory testing DB
// Mock API responses
```

**Release:**
```swift
// Minimal logging
// Production DB with encryption
// Real API calls
```

### App Store Submission Checklist
- [ ] Privacy Policy (использование камеры для QR)
- [ ] App Store screenshots (5.5", 6.5")
- [ ] App description (RU/EN)
- [ ] Keywords: warehouse, inventory, QR, offline
- [ ] Age rating: 4+
- [ ] Encryption: NO (только для API ключей)

---

## 📈 Версии и Roadmap

### v1.2 (Current) — Foundation
**Срок:** 4-5 месяцев

✅ CRUD для items, stock, kits  
✅ FTS5 + Vector search  
✅ PDF import  
✅ QR generation/scanning  
✅ Export to ZIP  
✅ Optional OpenAI integration  

---

### v1.3 — Enhanced Features
**Срок:** +2 месяца

🎯 Undo/Redo система  
🎯 Batch operations (массовое редактирование)  
🎯 Advanced filters and sorting  
🎯 Analytics dashboard  
🎯 Low stock alerts  
🎯 Dark Mode polish  

---

### v1.4 — Cloud Sync
**Срок:** +2 месяца

☁️ iCloud sync (опционально)  
☁️ Import/Export Excel (XLSX)  
☁️ Multi-device support  
☁️ Backup history  
☁️ Collaborative features  

---

### v2.0 — Advanced AI
**Срок:** +3 месяца

🤖 Qdrant Edge для векторного поиска  
🤖 Local LLM (Llama.cpp) вместо OpenAI  
🤖 Advanced analytics с ML predictions  
🤖 Computer Vision для фото классификации  
🔒 SQLCipher encryption  
⚡ Performance optimizations  

---

## 🎓 Best Practices

### Code Style
```swift
// ✅ ХОРОШО
func fetchItems(category: String? = nil) async throws -> [Item] {
    try await database.read { db in
        var request = Item.all()
        if let category = category {
            request = request.filter(Column("category") == category)
        }
        return try request.fetchAll(db)
    }
}

// ❌ ПЛОХО
func getItems(_ cat: String?) async throws -> [Item] {
    let db = DatabaseManager.shared.dbQueue
    return try await db.read { database in
        if cat != nil {
            return try Item.filter(Column("category") == cat!).fetchAll(database)
        }
        return try Item.fetchAll(database)
    }
}
```

### Error Handling
```swift
// ✅ Специфичные ошибки
enum InventoryError: LocalizedError {
    case insufficientStock(available: Int, required: Int)
    
    var errorDescription: String? {
        switch self {
        case .insufficientStock(let available, let required):
            return "Недостаточно: доступно \(available), требуется \(required)"
        }
    }
}

// ❌ Общие ошибки
enum AppError: Error {
    case error
}
```

### Memory Management
```swift
// ✅ Weak references для delegates
class SearchViewModel: ObservableObject {
    weak var delegate: SearchDelegate?
}

// ✅ @MainActor для UI
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var stats: Stats
}

// ❌ Strong reference cycles
class ViewModel {
    var closure: (() -> Void)?
    
    func setup() {
        closure = {
            self.doSomething() // ⚠️ Retain cycle
        }
    }
}
```

---

## 📚 Ресурсы

### Документация
- [GRDB Documentation](https://github.com/groue/GRDB.swift)
- [Apple SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

### Инструменты
- Xcode Instruments (Profiling)
- SwiftLint (Code style)
- SwiftFormat (Auto-formatting)

---

## ✅ Итоговый Checklist

### Перед началом разработки
- [ ] Xcode 15+ установлен
- [ ] Apple Developer аккаунт настроен
- [ ] Git repository создан
- [ ] Документация прочитана
- [ ] Тестовые данные подготовлены

### MVP (v1.2) Ready когда:
- [ ] Все 10 спринтов завершены
- [ ] Unit tests coverage > 70%
- [ ] UI tests для critical paths
- [ ] Performance: < 100ms для search
- [ ] Memory: No leaks (Instruments)
- [ ] Accessibility: VoiceOver support
- [ ] TestFlight beta с 10+ пользователями

---

## 📞 Контакты и поддержка

**Project Owner:** [Ваше имя]  
**Tech Lead:** [Ваше имя]  
**Status:** ✅ Ready for Development  

---

**Последнее обновление:** 05.10.2025  
**Версия документа:** 1.2 Final
    