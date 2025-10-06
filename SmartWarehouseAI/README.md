# 📦 Smart Warehouse AI

iOS приложение для офлайн-учёта склада запчастей с AI-возможностями.

## ✅ Статус проекта

**Версия:** 1.0
**Статус:** Инициализирован и готов к разработке
**Последняя сборка:** ✅ BUILD SUCCEEDED

## 🏗️ Реализованная структура

```
SmartWarehouseAI/
├── SmartWarehouseAI.xcodeproj/       # Xcode проект
└── SmartWarehouseAI/
    ├── App/
    │   └── AppSettings.swift          # Настройки приложения
    ├── Core/
    │   ├── Database/
    │   │   ├── DatabaseManager.swift  # GRDB менеджер БД
    │   │   └── Models/
    │   │       ├── Item.swift         # Модель товара
    │   │       ├── Stock.swift        # Модель остатков
    │   │       ├── Kit.swift          # Модель комплекта
    │   │       └── Part.swift         # Модель компонента
    │   ├── CRUD/                      # (готово к реализации)
    │   ├── Logic/                     # (готово к реализации)
    │   ├── Search/                    # (готово к реализации)
    │   ├── Integrations/              # (готово к реализации)
    │   └── Security/
    │       └── KeychainHelper.swift   # Безопасное хранение ключей
    └── UI/
        ├── DashboardView.swift        # Главная панель
        ├── ItemsView.swift            # Каталог товаров
        ├── InventoryView.swift        # Управление остатками
        ├── SearchView.swift           # Поиск
        └── SettingsView.swift         # Настройки
```

## 🛠️ Технологии

- **Платформа:** iOS 15+, macOS 12+ (Mac Catalyst)
- **Язык:** Swift 5.0+
- **UI:** SwiftUI
- **БД:** GRDB.swift v6.29.3
- **Архивирование:** ZIPFoundation v0.9.19

## 🚀 Сборка проекта

### Требования

- macOS 12.0+
- Xcode 15.0+
- Swift 5.9+

### Команды сборки

```bash
# Через Xcode
open SmartWarehouseAI.xcodeproj

# Через командную строку
cd SmartWarehouseAI
xcodebuild -project SmartWarehouseAI.xcodeproj \
           -scheme SmartWarehouseAI \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           build
```

## 📊 Текущий функционал

### ✅ Реализовано

**Спринт 1: База и CRUD** ✅
- [x] Базовая структура проекта
- [x] Интеграция GRDB для работы с БД
- [x] Модели данных (Item, Stock, Kit, Part)
- [x] DatabaseManager с CRUD операциями и миграциями
- [x] **ItemService** — полный CRUD для товаров
- [x] **StockService** — управление остатками с поддержкой min/max уровней
- [x] **KitService** — управление комплектами и компонентами
- [x] **InventoryLogic** — бизнес-логика сборки/разборки комплектов
- [x] UI экраны подключены к сервисам
- [x] KeychainHelper, AppSettings, TestDataSeeder

**Спринт 2: PDF Import** ✅
- [x] **PDFParserStrategy** — протокол для парсеров
- [x] **TableBasedPDFParser** — парсинг структурированных PDF (таблицы, списки)
- [x] **OCRBasedPDFParser** — Vision Framework OCR для сканов
- [x] **PDFParserFactory** — автовыбор парсера
- [x] **PDFImportService** — полный workflow импорта
- [x] **PDFImportView** — UI с валидацией и отчётами
- [x] Интеграция в ItemsView (кнопка Import PDF)
- [x] Поддержка русского и английского языков в OCR

**Спринт 3: Search** ✅
- [x] **FTS5Search** — полнотекстовый поиск через SQLite FTS5
- [x] **EmbeddingEngine** — векторные эмбеддинги через NLEmbedding
- [x] **VectorStore** — хранение и поиск векторов по сходству
- [x] **SearchService** — гибридный поиск (FTS5 + Vector) с RRF
- [x] **SearchView** — UI с режимами поиска и статистикой
- [x] Auto mode detection (SKU/single/multi-word)
- [x] BM25 ranking + Cosine similarity
- [x] Debounced search с cancellation

### 🔜 Следующие шаги (согласно плану)

1. **Спринт 4:** Остатки UI + отчёты ⏭️
2. **Спринт 5:** Логика комплектов
3. **Спринт 6-7:** QR-система + экспорт
4. **Спринт 8-10:** UI финализация + AI интеграция + тестирование

## 📁 База данных

### Таблицы

- **items** — каталог товаров (name, sku, description, category, barcode)
- **stocks** — остатки (itemId, quantity, location, minQuantity, maxQuantity)
- **kits** — комплекты (name, sku, description)
- **parts** — компоненты комплектов (kitId, itemId, quantity)
- **items_fts** — FTS5 виртуальная таблица для полнотекстового поиска
- **item_vectors** — векторные эмбеддинги для семантического поиска

### Индексы

- `idx_items_sku` — быстрый поиск по SKU
- `idx_stocks_itemId` — связь остатков с товарами
- `idx_kits_sku` — поиск комплектов
- `idx_parts_kitId`, `idx_parts_itemId` — связи компонентов

## 🔑 Основные файлы

| Файл | Назначение |
|------|-----------|
| `SmartWarehouseAIApp.swift` | Точка входа приложения |
| `ContentView.swift` | Главный TabView |
| `DatabaseManager.swift` | GRDB менеджер с миграциями |
| `KeychainHelper.swift` | Работа с Keychain для API ключей |
| `AppSettings.swift` | Настройки через UserDefaults |

## 📖 Документация

Полный план проекта: [final_project_plan.md](../final_project_plan.md)

## 🎯 Roadmap

- **v1.0** (текущая) — Базовая инфраструктура ✅
- **v1.1** — CRUD + PDF импорт ✅
- **v1.2** — Умный поиск (FTS5 + Vector) ✅
- **v1.3** — MVP с остатками UI, QR, экспорт (в процессе)
- **v1.4** — Расширенные фичи (Undo/Redo, Analytics)
- **v1.5** — Cloud Sync (iCloud)
- **v2.0** — Advanced AI (Локальный LLM, Computer Vision)

## 📞 Разработка

**Bundle ID:** com.smartwarehouse.ai
**Deployment Target:** iOS 15.0
**Build System:** Xcode Build System

---

**Последнее обновление:** 06.10.2025
**Статус сборки:** ✅ BUILD SUCCEEDED
**Готовность к продакшену:** 45% (Спринты 1-3 завершены)
