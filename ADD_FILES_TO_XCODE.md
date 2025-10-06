# 📝 Инструкция: Добавление файлов в Xcode проект

## Файлы для добавления

Следующие файлы созданы, но не добавлены в Xcode проект:

1. **`SmartWarehouseAI/UI/StockDetailView.swift`**
   - UI для редактирования остатков
   - QuickAdjustmentView для быстрых изменений

2. **`SmartWarehouseAI/UI/AddStockView.swift`**
   - UI для добавления новых остатков
   - Выбор товара, установка количества, локации

---

## Способ 1: Через Xcode GUI (Рекомендуется)

### Шаги:

1. **Открыть проект:**
   ```bash
   open SmartWarehouseAI/SmartWarehouseAI.xcodeproj
   ```

2. **В Project Navigator:**
   - Найти папку **`SmartWarehouseAI > UI`**
   - Правый клик на папку `UI`
   - Выбрать **"Add Files to SmartWarehouseAI..."**

3. **В диалоге:**
   - Перейти в папку: `SmartWarehouseAI/UI/`
   - Выбрать файлы:
     - `StockDetailView.swift`
     - `AddStockView.swift`
   - ✅ Убедиться, что галочка **"Copy items if needed"** СНЯТА
   - ✅ Убедиться, что галочка **"Add to targets: SmartWarehouseAI"** УСТАНОВЛЕНА
   - ✅ Убедиться, что **"Create groups"** выбрано
   - Нажать **"Add"**

4. **Проверка:**
   - Файлы должны появиться в Project Navigator под папкой `UI`
   - В правой панели (File Inspector) должно быть указано:
     - Target Membership: ✅ SmartWarehouseAI

5. **Сборка:**
   ```bash
   # Или в Xcode: Cmd+B
   xcodebuild -project SmartWarehouseAI.xcodeproj \
              -scheme SmartWarehouseAI \
              -destination 'platform=iOS Simulator,name=iPhone 17' \
              build
   ```

---

## Способ 2: Через командную строку

### Вариант A: С помощью xcodeproj gem

```bash
# Установить gem (если не установлен)
gem install xcodeproj

# Запустить скрипт
ruby << 'RUBY_EOF'
require 'xcodeproj'

project_path = 'SmartWarehouseAI/SmartWarehouseAI.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Найти UI group
main_group = project.main_group['SmartWarehouseAI']
ui_group = main_group['UI']

# Добавить файлы
files = [
  'StockDetailView.swift',
  'AddStockView.swift'
]

target = project.targets.first

files.each do |filename|
  file_ref = ui_group.new_reference(filename)
  target.add_file_references([file_ref])
  puts "Added #{filename}"
end

project.save
puts "Project saved successfully!"
RUBY_EOF
```

### Вариант B: Вручную через текстовый редактор (НЕ рекомендуется)

⚠️ **Внимание:** Этот способ может повредить проект. Используйте только если понимаете формат .pbxproj

```bash
# 1. Сделать backup
cp SmartWarehouseAI/SmartWarehouseAI.xcodeproj/project.pbxproj \
   SmartWarehouseAI/SmartWarehouseAI.xcodeproj/project.pbxproj.backup

# 2. Отредактировать вручную
# (требуется знание формат PBXProj)

# 3. В случае ошибки восстановить
cp SmartWarehouseAI/SmartWarehouseAI.xcodeproj/project.pbxproj.backup \
   SmartWarehouseAI/SmartWarehouseAI.xcodeproj/project.pbxproj
```

---

## Проверка после добавления

### 1. Компиляция
```bash
cd SmartWarehouseAI
xcodebuild -project SmartWarehouseAI.xcodeproj \
           -scheme SmartWarehouseAI \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           clean build
```

**Ожидаемый результат:**
```
** BUILD SUCCEEDED **
```

### 2. Проверка в Xcode

1. Открыть Project Navigator (Cmd+1)
2. Развернуть `SmartWarehouseAI > UI`
3. Должны быть видны:
   - ✅ StockDetailView.swift
   - ✅ AddStockView.swift
4. Файлы НЕ должны быть серыми (это означало бы, что они не в target)

### 3. Тест функциональности

Запустить приложение и проверить:
- **Inventory tab** → список остатков загружается
- Нажать на остаток → открывается **StockDetailView**
- Нажать "+" в toolbar → открывается **AddStockView**

---

## Troubleshooting

### Ошибка: "Cannot find 'StockDetailView' in scope"

**Причина:** Файл не добавлен в target

**Решение:**
1. Выбрать файл в Project Navigator
2. В File Inspector (правая панель)
3. Убедиться, что галочка **Target Membership > SmartWarehouseAI** установлена

---

### Ошибка: "No such file or directory"

**Причина:** Xcode ищет файл в неправильной папке

**Решение:**
1. Удалить файл из проекта (Delete Reference)
2. Добавить заново через "Add Files to SmartWarehouseAI..."
3. Убедиться, что галочка "Copy items if needed" СНЯТА

---

### Ошибка: Файлы серые в Project Navigator

**Причина:** Файлы не добавлены в target или не существуют на диске

**Решение:**
1. Проверить, что файлы физически существуют:
   ```bash
   ls -la SmartWarehouseAI/UI/StockDetailView.swift
   ls -la SmartWarehouseAI/UI/AddStockView.swift
   ```
2. Если файлов нет — они были удалены, нужно создать заново
3. Если файлы есть — удалить reference и добавить заново

---

## После успешной сборки

1. **Запустить приложение:**
   ```bash
   # В Xcode: Cmd+R
   # Или выбрать симулятор и нажать Play
   ```

2. **Протестировать новую функциональность:**
   - Открыть **Inventory** tab
   - Проверить фильтры (All/Low/Out/Normal)
   - Нажать на элемент → редактирование
   - Изменить quantity и сохранить
   - Нажать "+" → добавить новый остаток

3. **Зафиксировать изменения:**
   ```bash
   git add .
   git commit -m "✨ Sprint 4: Enhanced Inventory UI with CRUD

   - Added StockWithItem model with status indicators
   - Enhanced StockService with JOIN queries
   - Completely redesigned InventoryView with filters
   - Added StockDetailView for editing stock
   - Added AddStockView for creating new stock
   - Summary statistics and search functionality
   "
   ```

---

## Полезные команды

```bash
# Очистить build cache
cd SmartWarehouseAI
rm -rf ~/Library/Developer/Xcode/DerivedData/SmartWarehouseAI-*

# Переиндексировать проект
# В Xcode: Product → Clean Build Folder (Cmd+Shift+K)

# Показать все файлы в UI папке
find SmartWarehouseAI/UI -name "*.swift"

# Проверить, что файлы в git
git status
```

---

**Документация обновлена:** 06.10.2025
**Sprint:** 4 — Inventory UI Enhancement
