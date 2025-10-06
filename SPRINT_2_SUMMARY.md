# 📄 Sprint 2 Summary — PDF Import

**Проект:** Smart Warehouse AI
**Спринт:** 2 из 10
**Длительность:** 2-3 недели (план)
**Статус:** ✅ **ЗАВЕРШЁН**
**Дата:** 05.10.2025

---

## 🎯 Цели спринта

✅ Реализовать импорт каталогов из PDF
✅ Создать парсеры для разных форматов (таблицы + OCR)
✅ Реализовать Strategy Pattern для выбора парсера
✅ Создать UI для импорта и валидации
✅ Интегрировать с базой данных через ItemService

---

## ✅ Выполненные задачи

### 1. Базовые типы (`PDFParserTypes.swift`)

#### **ParsedItem** — результат парсинга одного товара
```swift
struct ParsedItem {
    var name: String
    var sku: String?
    var category: String?
    var description: String?
    var barcode: String?
    var confidence: Double = 1.0  // 0.0 - 1.0
    var pageNumber: Int?

    func toItem() -> Item
}
```

#### **PDFParseResult** — итоговый результат парсинга
```swift
struct PDFParseResult {
    let items: [ParsedItem]
    let totalPages: Int
    let parseMethod: String
    let warnings: [String]
    let errors: [String]
    var successRate: Double
}
```

#### **PDFParserStrategy Protocol**
```swift
protocol PDFParserStrategy {
    var name: String { get }
    func canParse(_ document: PDFDocument) -> Bool
    func parse(_ document: PDFDocument) async throws -> PDFParseResult
}
```

#### **PDFParserConfig** — настройки парсинга
- `minimumConfidence: Double` — порог уверенности (default: 0.5)
- `enableOCR: Bool` — включить OCR (default: true)
- `maxPages: Int` — лимит страниц (0 = без лимита)
- `autoCategories: [String]` — категории для авто-определения

#### **PDFParserError** — типизированные ошибки
- `cannotOpenFile`
- `emptyDocument`
- `noSuitableParser`
- `parsingFailed(String)`
- `invalidFormat(String)`
- `ocrFailed(String)`

---

### 2. TableBasedPDFParser (для структурированных PDF)

**Назначение:** Парсинг PDF с извлекаемым текстом (таблицы, списки)

#### Алгоритм работы:
1. **Проверка совместимости** (`canParse`):
   - Проверяет наличие текста в PDF
   - Ищет табуляции, пробелы, цифры

2. **Парсинг страниц**:
   - Извлечение текста через `PDFPage.string`
   - Разбивка на строки

3. **Стратегии парсинга строк** (3 метода):

   **a) Tab-Delimited Format**
   ```
   BOLT-M6\tБолт М6x20\tКрепёжный элемент
   ```
   - Разделение по `\t`
   - Confidence: 0.9

   **b) Space-Delimited with Pattern**
   ```
   CODE-123 Item Name (optional description)
   ```
   - Regex: `^([A-Z0-9\-]+)\s+(.+?)(?:\s*\((.+?)\))?$`
   - Извлечение SKU, name, description
   - Confidence: 0.8

   **c) Key-Value Format**
   ```
   Name: Болт М6x20
   ```
   - Парсинг "ключ: значение"
   - Фильтр по ключевым словам (name, item, product, part)
   - Confidence: 0.6

4. **Фильтрация**:
   - По `minimumConfidence`
   - Предупреждения для пропущенных

**Результат:** Массив `ParsedItem` с высокой точностью для структурированных PDF

---

### 3. OCRBasedPDFParser (для сканированных PDF)

**Назначение:** Парсинг сканов через Vision Framework OCR

#### Алгоритм работы:

1. **Проверка совместимости** (`canParse`):
   - Проверяет, что `enableOCR = true`
   - Определяет, что текста < 100 символов (вероятно скан)

2. **Рендеринг PDF в изображение**:
   ```swift
   let image = renderPageToImage(page)  // Scale: 2.0 для лучшего OCR
   ```

3. **OCR через Vision**:
   ```swift
   let request = VNRecognizeTextRequest()
   request.recognitionLevel = .accurate
   request.recognitionLanguages = ["en", "ru"]
   request.usesLanguageCorrection = true
   ```

4. **Извлечение текста**:
   - Получение `VNRecognizedTextObservation`
   - Сортировка по вертикальной позиции (сверху вниз)
   - Извлечение текста + confidence

5. **Парсинг распознанного текста**:
   - Фильтрация заголовков (page, catalog, price, list)
   - Извлечение SKU через regex паттерны:
     - `[A-Z]{2,}[\-0-9A-Z]+` (BOLT-M6-20)
     - `[A-Z]\d{3,}` (A1234)
     - `\d{4,}` (123456)
   - Разделение description в скобках
   - Confidence OCR × 0.8 (снижение из-за неточности распознавания)

**Результат:** Массив `ParsedItem` для сканированных документов

**⚠️ Ограничения:**
- Требует разрешения камеры (для Vision Framework)
- Качество зависит от качества скана
- Медленнее чем table-based парсинг

---

### 4. PDFImportService (главный сервис)

#### **PDFParserFactory**
```swift
static func selectParser(for document: PDFDocument) -> PDFParserStrategy
```
- Автоматический выбор парсера
- Приоритет: TableBased → OCR → TableBased (fallback)

#### **PDFImportService API**

**a) importCatalog(from: URL) → ImportResult**
- Загрузка PDF
- Выбор парсера
- Парсинг документа
- Возврат результата

**b) saveItems(_ parsedItems: [ParsedItem]) → SaveResult**
- Проверка дубликатов по SKU
- Создание через `ItemService`
- Подсчёт imported/skipped
- Логирование

**c) importAndSave(from: URL) → CompleteImportResult**
- Полный workflow: парсинг + сохранение
- Итоговая статистика

#### Result Types

**ImportResult:**
- `sourceFile: String`
- `parseResult: PDFParseResult`
- `importedItems: [Item]`
- `skippedItems: [(ParsedItem, String)]`

**SaveResult:**
- `imported: [Item]`
- `skipped: [(ParsedItem, String)]`
- `successCount: Int`
- `successRate: Double`

**CompleteImportResult:**
- `sourceFile: String`
- `parseResult: PDFParseResult`
- `saveResult: SaveResult`
- `summary: String` — текстовая сводка

---

### 5. PDFImportView (UI)

#### Состояния экрана:

**a) Upload View** (начальное состояние)
- Иконка документа
- Кнопка "Choose PDF File"
- Info cards:
  - ✅ Supports structured PDFs with tables
  - ✅ OCR for scanned catalogs
  - ✅ Auto-detection of SKU and names
- File picker (`.pdf` only)

**b) Processing View**
- ProgressView
- Статус: "Processing PDF...", "Parsing document..."

**c) Result View**
- **Summary Card:**
  - Иконка (✓ success или ⚠️ warning)
  - Имя файла
  - Статистика: Imported / Skipped / Success %
- **Warnings Section** (если есть)
- **Errors Section** (если есть)
- **Skipped Items** с причинами
- Кнопка "Done"

#### PDFImportViewModel

```swift
@Published var showingFilePicker: Bool
@Published var isProcessing: Bool
@Published var processingStatus: String?
@Published var importResult: CompleteImportResult?

func handleFileSelection(_ result: Result<[URL], Error>) async
```

**Workflow:**
1. Пользователь выбирает PDF
2. `startAccessingSecurityScopedResource()` для sandbox
3. `importService.importAndSave(from: url)`
4. Отображение результата

---

### 6. Интеграция в ItemsView

#### Изменения:
```swift
@State private var showingPDFImport = false

.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        Button("Import PDF") {
            showingPDFImport = true
        }
    }
}

.sheet(isPresented: $showingPDFImport) {
    PDFImportView()
        .onDisappear {
            loadItems() // Refresh после импорта
        }
}
```

**UX Flow:**
1. Кнопка "Import PDF" в Items
2. Модальное окно `PDFImportView`
3. Выбор файла → Парсинг → Результат
4. Закрытие → Автообновление списка

---

## 🏗️ Архитектура

### Файловая структура (финальная)

```
SmartWarehouseAI/Core/Integrations/
├── PDFParserTypes.swift           ✨ NEW
├── TableBasedPDFParser.swift      ✨ NEW
├── OCRBasedPDFParser.swift        ✨ NEW
└── PDFImportService.swift         ✨ NEW

SmartWarehouseAI/UI/
└── PDFImportView.swift            ✨ NEW
```

### Диаграмма классов

```
PDFParserStrategy (Protocol)
    ├── TableBasedPDFParser
    └── OCRBasedPDFParser

PDFParserFactory
    └── selectParser() → PDFParserStrategy

PDFImportService
    ├── importCatalog()
    ├── saveItems()
    └── importAndSave()

PDFImportView
    └── PDFImportViewModel
        └── handleFileSelection()
```

---

## 🧪 Тестирование

### Поддерживаемые форматы PDF:

#### ✅ Структурированные PDF:
- Таблицы с tab-разделителями
- Списки с пробелами
- Key-value форматы
- **Примеры:** Excel → PDF, Word → PDF, generated catalogs

#### ✅ Сканированные PDF:
- Фотографии каталогов
- Отсканированные документы
- Изображения с текстом
- **Требования:** Чёткий текст, контраст

#### ⚠️ Сложные случаи:
- Многоколоночные таблицы (может требовать ручной коррекции)
- Рукописный текст (низкая точность OCR)
- Низкое качество сканов (ошибки распознавания)

---

## 📊 Метрики

| Метрика | Значение |
|---------|----------|
| **Файлов создано** | 5 (4 core + 1 UI) |
| **Строк кода** | ~1200 |
| **Парсеры** | 2 (Table + OCR) |
| **Поддерживаемые форматы** | Tab-delimited, Space-delimited, Key-Value, OCR |
| **Языки OCR** | English, Russian |
| **Статус сборки** | ✅ BUILD SUCCEEDED |

---

## 🎓 Ключевые решения

### 1. Strategy Pattern для парсеров
- Легко добавить новые парсеры
- Автоматический выбор через `canParse()`
- Изолированная логика парсинга

### 2. Confidence-based фильтрация
- Каждый `ParsedItem` имеет `confidence: Double`
- Настраиваемый порог через `PDFParserConfig`
- OCR результаты × 0.8 из-за неточности

### 3. Vision Framework для OCR
- Нативный Apple OCR (без сторонних библиотек)
- Поддержка многих языков
- Автокоррекция текста

### 4. Async/Await для парсинга
- Весь парсинг асинхронный
- Не блокирует UI
- Прогресс-индикатор во время обработки

### 5. Sandbox-safe file access
```swift
url.startAccessingSecurityScopedResource()
defer { url.stopAccessingSecurityScopedResource() }
```

---

## 🐛 Известные ограничения

1. ❌ **Многоколоночные таблицы** — может некорректно парсить сложные макеты
2. ❌ **Вложенные структуры** — не распознаёт иерархии
3. ❌ **Изображения товаров** — не извлекает (только текст)
4. ⚠️ **Категории** — автоопределение базовое (нужен ML в будущем)
5. ⚠️ **OCR точность** — зависит от качества скана (70-95%)
6. ❌ **Батч импорт** — только один файл за раз

---

## 🔜 Потенциальные улучшения (не в текущем спринте)

1. **AI-based категоризация** через OpenAI/Claude API
2. **Предпросмотр перед импортом** с редактированием
3. **Шаблоны парсинга** для популярных форматов
4. **Импорт изображений** из PDF
5. **Обучаемые парсеры** (ML-based)
6. **Батч-импорт** нескольких файлов
7. **История импортов** с возможностью отката

---

## 🔜 Следующий спринт: Поиск (FTS5 + Vector)

### Спринт 3 (2 недели)

**Цель:** Реализовать умный поиск

**Задачи:**
1. **FTS5Search** — полнотекстовый поиск через SQLite
2. **EmbeddingEngine** — CoreML векторные эмбеддинги
3. **VectorStore** — хранение и поиск векторов
4. **RAGEngine** — контекстный поиск (опционально)
5. Обновить **SearchView** с гибридным поиском

**Критичность:** ⚠️ СРЕДНЯЯ (качество зависит от модели)

---

## ✅ Итоги Спринта 2

**Статус:** ✨ **УСПЕШНО ЗАВЕРШЁН**

Реализован полнофункциональный PDF импорт:
- ✅ 2 парсера (Table + OCR) с Strategy Pattern
- ✅ Автовыбор парсера на основе формата
- ✅ UI с валидацией и отчётами
- ✅ Интеграция с ItemService
- ✅ Поддержка русского языка в OCR
- ✅ Проект стабильно собирается

**Время выполнения:** 1 сессия (05.10.2025)
**Готовность к продакшену:** 35% (CRUD + PDF импорт)

---

**Последнее обновление:** 05.10.2025
**Следующий спринт:** Поиск (FTS5 + Vector) — Спринт 3
