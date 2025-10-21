local component = require("component")
local event = require("event")
local serialization = require("serialization")
local term = require("term")
local thread = require("thread")
local computer = require("computer")
local filesystem = require("filesystem")

-- Конфигурация системы
local STORAGE_CONFIG = {
    primaryStorage = "/home/",
    maxMemoryItems = 4000,
    maxCraftables = 2000,
    chunkSize = 50,
    saveChunkSize = 500  -- Размер чанка для сохранения
}

if not component.isAvailable("me_interface") then
  print("Ошибка: ME интерфейс не найден!")
  print("Убедитесь что ME интерфейс подключен к компьютеру")
  return
end

local me = component.me_interface
local running = true
local craftThread = nil
local craftingEnabled = false

local craftDB = {}  
local configFile = "/home/craft_config.txt"
local meKnowledgeFile = "/home/me_knowledge.txt"
local essentialFile = "/home/essential_data.txt"

local meKnowledge = {
    items = {},          
    craftables = {},     
    cpus = {},           
    patterns = {},       
    craftTimes = {},     
    craftHistory = {},   
    researchDB = {}      
}

-- Функция очистки памяти
local function freeMemory()
    collectgarbage()
    local temp = {}
    for i = 1, 20 do  -- Уменьшил размер для экономии памяти
        temp[i] = {}
        for j = 1, 3 do
            temp[i][j] = string.rep("x", 20)
        end
    end
    temp = nil
    collectgarbage()
end

-- ПОЭТАПНОЕ СОХРАНЕНИЕ БОЛЬШИХ ТАБЛИЦ ЧАНКАМИ
local function saveLargeTableChunked(filename, data, chunkSize)
    chunkSize = chunkSize or STORAGE_CONFIG.saveChunkSize
    
    if not data or type(data) ~= "table" then
        return false
    end
    
    -- Если таблица маленькая, сохраняем целиком
    if #data <= chunkSize then
        return saveDataToFile(filename, data)
    end
    
    print("💾 Поэтапное сохранение " .. #data .. " записей...")
    
    -- Сохраняем чанками
    local totalChunks = math.ceil(#data / chunkSize)
    local baseName = filename:gsub("%.txt$", "")
    
    -- Сохраняем метаданные
    local metadata = {
        totalChunks = totalChunks,
        chunkSize = chunkSize,
        totalRecords = #data,
        baseName = baseName
    }
    
    if not saveDataToFile(baseName .. "_meta.txt", metadata) then
        return false
    end
    
    -- Сохраняем каждый чанк
    for chunkIndex = 1, totalChunks do
        local startIndex = (chunkIndex - 1) * chunkSize + 1
        local endIndex = math.min(chunkIndex * chunkSize, #data)
        
        local chunkData = {}
        for i = startIndex, endIndex do
            table.insert(chunkData, data[i])
        end
        
        local chunkFilename = baseName .. "_chunk_" .. chunkIndex .. ".txt"
        if not saveDataToFile(chunkFilename, chunkData) then
            print("❌ Ошибка сохранения чанка " .. chunkIndex)
            return false
        end
        
        print("   ✅ Чанк " .. chunkIndex .. "/" .. totalChunks .. " сохранен")
        freeMemory()
        os.sleep(0.1)  -- Даем время на освобождение памяти
    end
    
    print("✅ Все чанки сохранены")
    return true
end

-- ПОЭТАПНАЯ ЗАГРУЗКА БОЛЬШИХ ТАБЛИЦ
local function loadLargeTableChunked(filename)
    local baseName = filename:gsub("%.txt$", "")
    
    -- Сначала пробуем загрузить целиком (для обратной совместимости)
    local fullData = loadDataFromFile(filename)
    if fullData then
        return fullData
    end
    
    -- Загружаем метаданные
    local metadata = loadDataFromFile(baseName .. "_meta.txt")
    if not metadata then
        return nil
    end
    
    print("📁 Загрузка " .. metadata.totalRecords .. " записей из " .. metadata.totalChunks .. " чанков...")
    
    local result = {}
    
    -- Загружаем каждый чанк
    for chunkIndex = 1, metadata.totalChunks do
        local chunkFilename = baseName .. "_chunk_" .. chunkIndex .. ".txt"
        local chunkData = loadDataFromFile(chunkFilename)
        
        if chunkData then
            for _, item in ipairs(chunkData) do
                table.insert(result, item)
            end
            print("   ✅ Чанк " .. chunkIndex .. "/" .. metadata.totalChunks .. " загружен")
        else
            print("❌ Ошибка загрузки чанка " .. chunkIndex)
            return nil
        end
        
        freeMemory()
        os.sleep(0.1)
    end
    
    print("✅ Все чанки загружены")
    return result
end

-- УПРОЩЕННАЯ ФУНКЦИЯ СОХРАНЕНИЯ ДАННЫХ
local function saveDataToFile(filename, data)
    for attempt = 1, 2 do  -- Уменьшил количество попыток
        local file, err = io.open(filename, "w")
        if file then
            -- Ограничиваем размер сериализуемых данных
            local serialized = serialization.serialize(data)
            if #serialized > 100000 then  -- Если данные слишком большие
                print("⚠️  Большой объем данных: " .. #serialized .. " байт")
            end
            
            file:write(serialized)
            file:close()
            
            -- Быстрая проверка записи
            local checkFile = io.open(filename, "r")
            if checkFile then
                local content = checkFile:read("*a")
                checkFile:close()
                if content and content ~= "" then
                    return true
                end
            end
        end
        os.sleep(0.3)
    end
    return false
end

-- УПРОЩЕННАЯ ФУНКЦИЯ ЗАГРУЗКИ ДАННЫХ
local function loadDataFromFile(filename)
    for attempt = 1, 2 do
        local file = io.open(filename, "r")
        if file then
            local content = file:read("*a")
            file:close()
            if content and content ~= "" then
                local success, data = pcall(serialization.unserialize, content)
                if success and data then
                    return data
                end
            end
        end
        os.sleep(0.3)
    end
    return nil
end

local function tableLength(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- ОПТИМИЗИРОВАННАЯ загрузка базы знаний
local function loadMEKnowledge()
    print("📁 Загрузка базы знаний ME системы...")
    
    -- Загружаем основные данные (они небольшие)
    local data = loadDataFromFile(essentialFile)
    if data then
        meKnowledge.patterns = data.patterns or {}
        meKnowledge.craftTimes = data.craftTimes or {}
        meKnowledge.cpus = data.cpus or {}
        print("✅ Основные данные загружены")
    end
    
    -- Пробуем загрузить предметы чанками
    meKnowledge.items = loadLargeTableChunked(meKnowledgeFile) or {}
    
    -- Загружаем крафты
    local craftablesData = loadDataFromFile("/home/craftables_data.txt")
    if craftablesData then
        meKnowledge.craftables = craftablesData
    else
        meKnowledge.craftables = {}
    end
    
    print("✅ База знаний загружена")
    print("   Предметы: " .. #meKnowledge.items)
    print("   Крафты: " .. #meKnowledge.craftables)
    print("   Паттерны: " .. tableLength(meKnowledge.patterns))
    
    return true
end

-- ОПТИМИЗИРОВАННОЕ сохранение базы знаний
local function saveMEKnowledge()
    print("💾 Сохранение базы знаний...")
    
    local success = true
    
    -- Сохраняем предметы чанками (если их много)
    if meKnowledge.items and #meKnowledge.items > STORAGE_CONFIG.saveChunkSize then
        if not saveLargeTableChunked(meKnowledgeFile, meKnowledge.items) then
            print("❌ Ошибка сохранения предметов")
            success = false
        end
    elseif meKnowledge.items then
        if not saveDataToFile(meKnowledgeFile, meKnowledge.items) then
            success = false
        end
    end
    
    -- Сохраняем крафты отдельно (они обычно меньше)
    if meKnowledge.craftables then
        if not saveDataToFile("/home/craftables_data.txt", meKnowledge.craftables) then
            success = false
        end
    end
    
    -- Всегда сохраняем основные данные
    local essentialData = {
        patterns = meKnowledge.patterns or {},
        craftTimes = meKnowledge.craftTimes or {},
        cpus = meKnowledge.cpus or {}
    }
    
    if not saveDataToFile(essentialFile, essentialData) then
        success = false
    end
    
    if success then
        print("✅ База знаний сохранена")
    else
        print("❌ Частичная ошибка сохранения")
    end
    
    return success
end

-- СОХРАНЕНИЕ ОСНОВНЫХ ДАННЫХ (упрощенное)
local function saveEssentialData()
    local essentialData = {
        patterns = meKnowledge.patterns or {},
        craftTimes = meKnowledge.craftTimes or {},
        cpus = meKnowledge.cpus or {}
    }
    
    return saveDataToFile(essentialFile, essentialData)
end

-- ЗАГРУЗКА КОНФИГУРАЦИИ АВТОКРАФТОВ
local function loadConfig()
    print("📁 Загрузка конфигурации автокрафтов...")
    
    local data = loadDataFromFile(configFile)
    if data then
        craftDB = data
        print("✅ Загружено автокрафтов: " .. tableLength(craftDB))
        return true
    end
    
    craftDB = {}
    print("📁 Файл конфигурации не найден")
    return false
end

-- СОХРАНЕНИЕ КОНФИГУРАЦИИ АВТОКРАФТОВ
local function saveConfig()
    return saveDataToFile(configFile, craftDB)
end

-- ОСТАЛЬНЫЕ ФУНКЦИИ БЕЗ ИЗМЕНЕНИЙ (для экономии места)

-- УЛУЧШЕННЫЙ показ страниц (35 строк)
local function showPaginated(data, title, itemsPerPage)
    if not data or #data == 0 then
        print("   Нет данных для отображения")
        print("\nНажмите Enter для продолжения...")
        io.read()
        return
    end
    
    itemsPerPage = itemsPerPage or 35
    local totalPages = math.ceil(#data / itemsPerPage)
    local currentPage = 1
    
    while true do
        term.clear()
        print("=== " .. title .. " ===")
        print("Страница " .. currentPage .. " из " .. totalPages)
        print()
        
        local startIndex = (currentPage - 1) * itemsPerPage + 1
        local endIndex = math.min(currentPage * itemsPerPage, #data)
        
        for i = startIndex, endIndex do
            if data[i] then
                print(data[i])
            end
        end
        
        print("\n" .. string.rep("=", 40))
        print("Навигация: [P]редыдущая | [N]следующая | [E]выход")
        
        local input = io.read():lower()
        if input == "n" and currentPage < totalPages then
            currentPage = currentPage + 1
        elseif input == "p" and currentPage > 1 then
            currentPage = currentPage - 1
        elseif input == "e" then
            break
        end
    end
end

-- ОПТИМИЗИРОВАННЫЙ АНАЛИЗ ME СИСТЕМЫ
local function analyzeMESystem()
    print("🔍 Запуск интеллектуального анализа ME системы...")
    
    -- Очистка старых данных с освобождением памяти
    meKnowledge.items = {}
    meKnowledge.craftables = {}
    collectgarbage()
    
    if not meKnowledge.cpus then meKnowledge.cpus = {} end
    if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
    if not meKnowledge.researchDB then meKnowledge.researchDB = {} end
    
    -- Анализ предметов с промежуточным сохранением
    print("📦 Анализ предметов в системе...")
    local success, items = pcall(me.getItemsInNetwork)
    if success and items then
        local itemCount = #items
        print("   Найдено предметов: " .. itemCount)
        
        -- Сохраняем каждые 200 предметов
        local saveInterval = 200
        local lastSave = 0
        
        for i = 1, itemCount do
            local item = items[i]
            if item and item.name then
                table.insert(meKnowledge.items, {
                    name = item.name,
                    size = item.size or 0,
                    label = item.label or "нет"
                })
            end
            
            -- Промежуточное сохранение и очистка памяти
            if i % saveInterval == 0 then
                print("   Обработано: " .. i .. "/" .. itemCount)
                saveEssentialData()
                freeMemory()
                lastSave = i
            end
        end
        
        print("✅ Предметов проанализировано: " .. #meKnowledge.items)
    else
        print("❌ Ошибка анализа предметов")
    end
    
    -- Анализ крафтов с оптимизацией памяти
    print("🛠️ Интеллектуальный анализ крафтов...")
    local success, craftables = pcall(me.getCraftables)
    if success and craftables then
        local craftableCount = #craftables
        print("   Найдено крафтов: " .. craftableCount)
        
        meKnowledge.craftables = {}
        meKnowledge.patterns = {}
        
        for i = 1, craftableCount do
            local craftable = craftables[i]
            if craftable and craftable.getItemStack then
                local itemSuccess, itemStack = pcall(craftable.getItemStack)
                if itemSuccess and itemStack and itemStack.name then
                    table.insert(meKnowledge.craftables, {
                        index = i,
                        itemStack = {
                            name = itemStack.name,
                            label = itemStack.label or "нет"
                        }
                    })
                    
                    meKnowledge.patterns[itemStack.name] = i
                end
            end
            
            -- Частая очистка памяти для крафтов
            if i % 50 == 0 then
                freeMemory()
            end
        end
        
        print("✅ Крафтов исследовано: " .. #meKnowledge.craftables)
    else
        print("❌ Ошибка анализа крафтов")
    end
    
    -- Анализ ЦП
    print("⚡ Анализ процессоров крафта...")
    local success, cpus = pcall(me.getCraftingCPUs)
    if success and cpus then
        meKnowledge.cpus = {}
        for i, cpu in ipairs(cpus) do
            if cpu then
                table.insert(meKnowledge.cpus, {
                    index = i,
                    busy = cpu.busy or false,
                    storage = cpu.storage or 0,
                    name = cpu.name or "ЦП #" .. i
                })
            end
        end
        print("✅ Процессоров найдено: " .. #meKnowledge.cpus)
    else
        print("❌ Ошибка анализа процессоров")
    end
    
    -- Финальное сохранение с оптимизацией
    freeMemory()
    
    -- Сохраняем основные данные сразу
    saveEssentialData()
    
    -- Сохраняем предметы и крафты с проверкой размера
    if #meKnowledge.items > 1000 then
        print("💾 Сохранение большого объема данных чанками...")
        saveLargeTableChunked(meKnowledgeFile, meKnowledge.items)
    else
        saveDataToFile(meKnowledgeFile, meKnowledge.items)
    end
    
    saveDataToFile("/home/craftables_data.txt", meKnowledge.craftables)
    
    print("\n🎉 Анализ завершен успешно!")
    print("📊 Итоги:")
    print("   📦 Предметы: " .. #meKnowledge.items)
    print("   🛠️ Крафты: " .. #meKnowledge.craftables)
    print("   🔗 Паттерны: " .. tableLength(meKnowledge.patterns))
    print("   ⚡ Процессоры: " .. #meKnowledge.cpus)
    
    print("\nНажмите Enter для продолжения...")
    io.read()
end

-- УМНЫЙ ПОИСК CRAFTABLE
local function findCraftableSmart(itemID, itemName)
    if meKnowledge.patterns and meKnowledge.patterns[itemID] then
        return meKnowledge.patterns[itemID]
    end
    
    if meKnowledge.craftables then
        for i, craftableInfo in ipairs(meKnowledge.craftables) do
            if craftableInfo.itemStack and craftableInfo.itemStack.name == itemID then
                meKnowledge.patterns[itemID] = i
                saveEssentialData()
                return i
            end
        end
    end
    
    return nil
end

local function getItemCount(itemID)
    if not meKnowledge.items then return 0 end
    for i, item in ipairs(meKnowledge.items) do
        if item.name == itemID then
            return item.size or 0
        end
    end
    return 0
end

local function updateItemCounts()
    local success, items = pcall(me.getItemsInNetwork)
    if success and items and meKnowledge.items then
        for i, item in ipairs(items) do
            if item and item.name then
                for j, knownItem in ipairs(meKnowledge.items) do
                    if knownItem.name == item.name then
                        knownItem.size = item.size or 0
                        break
                    end
                end
            end
        end
    end
end

local function getAvailableCPU(preferredCPUs, allowOtherCPUs)
    local success, cpus = pcall(me.getCraftingCPUs)
    if not success or not cpus then
        return nil
    end
    
    for _, cpuIndex in ipairs(preferredCPUs) do
        if cpus[cpuIndex] and not cpus[cpuIndex].busy then
            return cpuIndex
        end
    end
    
    if allowOtherCPUs then
        for i, cpu in ipairs(cpus) do
            if cpu and not cpu.busy then
                local isPreferred = false
                for _, preferredIndex in ipairs(preferredCPUs) do
                    if i == preferredIndex then
                        isPreferred = true
                        break
                    end
                end
                if not isPreferred then
                    return i
                end
            end
        end
    end
    
    return nil
end

local function requestCraft(itemID, amount, preferredCPUs, allowOtherCPUs, craftName)
    local craftableIndex = nil
    
    for name, data in pairs(craftDB) do
        if data.itemID == itemID then
            craftableIndex = data.craftableIndex
            break
        end
    end
    
    if not craftableIndex then
        craftableIndex = findCraftableSmart(itemID, craftName)
        if craftableIndex then
            for name, data in pairs(craftDB) do
                if data.itemID == itemID then
                    data.craftableIndex = craftableIndex
                    saveConfig()
                    break
                end
            end
        else
            print("❌ Не удалось найти крафт для " .. craftName)
            return false
        end
    end
    
    local success, craftables = pcall(me.getCraftables)
    if not success or not craftables or not craftables[craftableIndex] then
        print("❌ Крафт не найден: #" .. craftableIndex)
        return false
    end
    
    local craftable = craftables[craftableIndex]
    local craftSuccess, result = pcall(craftable.request, amount)
    
    if craftSuccess then
        if result then
            print("✅ Заказан крафт: " .. craftName .. " x" .. amount)
            return true
        else
            print("❌ Крафт недоступен: " .. craftName)
            return false
        end
    else
        print("❌ Ошибка заказа: " .. tostring(result))
        return false
    end
end

local function waitForCraft(itemID, targetAmount, craftName)
    local averageTime = meKnowledge.craftTimes and meKnowledge.craftTimes[itemID]
    local timeout = averageTime and (averageTime * 2 + 60) or 300
    local startTime = computer.uptime()
    
    while computer.uptime() - startTime < timeout do
        updateItemCounts()  
        local currentCount = getItemCount(itemID)
        local elapsed = math.floor(computer.uptime() - startTime)
        print("   📦 " .. currentCount .. "/" .. targetAmount .. " (" .. elapsed .. "с)")
        
        if currentCount >= targetAmount then
            print("✅ Готово: " .. craftName)
            
            if not meKnowledge.craftTimes or not meKnowledge.craftTimes[itemID] then
                local actualTime = computer.uptime() - startTime
                if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
                meKnowledge.craftTimes[itemID] = actualTime
                saveEssentialData()
            end
            
            return true
        end
        
        os.sleep(5)
    end
    
    print("❌ Таймаут ожидания: " .. craftName)
    return false
end

-- ОСНОВНОЙ ЦИКЛ АВТОКРАФТА
local function craftLoop()
    print("🚀 Запуск поддержки автокрафта...")
    
    while craftingEnabled do
        for name, craftData in pairs(craftDB) do
            if not craftingEnabled then break end
            
            updateItemCounts()
            local currentCount = getItemCount(craftData.itemID)
            
            if currentCount < craftData.targetAmount then
                local needed = craftData.targetAmount - currentCount
                print("\n🔍 " .. name .. ": " .. currentCount .. "/" .. craftData.targetAmount)
                print("🛠️ Нужно: " .. needed .. " шт.")
                
                local availableCPU = getAvailableCPU(craftData.preferredCPUs, craftData.allowOtherCPUs)
                
                if availableCPU then
                    if requestCraft(craftData.itemID, needed, craftData.preferredCPUs, craftData.allowOtherCPUs, name) then
                        waitForCraft(craftData.itemID, craftData.targetAmount, name)
                    end
                else
                    print("⏳ Все ЦП заняты, ждем...")
                    os.sleep(10)
                end
            end
            
            os.sleep(craftData.checkTimeout)
        end
        
        if craftingEnabled then
            print("\n--- 🔄 Цикл завершен ---")
            os.sleep(10)
        end
    end
end

-- ФУНКЦИЯ ПЕРЕКЛЮЧЕНИЯ АВТОКРАФТА
local function toggleAutoCraft()
    if craftingEnabled then
        craftingEnabled = false
        if craftThread then
            craftThread:join()
            craftThread = nil
        end
        print("🛑 Поддержка автокрафта остановлена")
    else
        if tableLength(craftDB) == 0 then
            print("❌ Нет автокрафтов для поддержки!")
            os.sleep(2)
            return
        end
        craftingEnabled = true
        craftThread = thread.create(craftLoop)
        print("🚀 Поддержка автокрафта запущена")
    end
    os.sleep(1)
end

-- УЛУЧШЕННЫЙ ИНТЕРФЕЙС ДОБАВЛЕНИЯ АВТОКРАФТА
local function addAutoCraft()
    term.clear()
    print("=== ➕ ДОБАВЛЕНИЕ АВТОКРАФТА ===")
    print()
    
    -- Показываем последние 10 предметов
    print("📦 Последние предметы в системе:")
    local recentItems = {}
    if meKnowledge.items and #meKnowledge.items > 0 then
        local startIndex = math.max(1, #meKnowledge.items - 9)
        for i = startIndex, #meKnowledge.items do
            if meKnowledge.items[i] then
                local item = meKnowledge.items[i]
                print("  " .. item.name .. " - " .. (item.size or 0) .. " шт. (" .. (item.label or "нет") .. ")")
                table.insert(recentItems, item)
            end
        end
    else
        print("  Нет данных о предметах")
    end
    
    print("\n" .. string.rep("=", 40))
    
    print("Введите название автокрафта:")
    local craftName = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if craftDB[craftName] then
        print("❌ Автокрафт с таким именем уже существует!")
        os.sleep(2)
        return
    end
    
    print("Введите ID предмета:")
    local itemID = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    local itemExists = false
    local itemLabel = ""
    if meKnowledge.items then
        for i, item in ipairs(meKnowledge.items) do
            if item.name == itemID then
                itemExists = true
                itemLabel = item.label or itemID
                break
            end
        end
    end
    
    if not itemExists then
        print("❌ Предмет не найден в системе!")
        os.sleep(2)
        return
    end
    
    print("Целевое количество:")
    local targetAmount = tonumber(io.read())
    
    if not targetAmount or targetAmount <= 0 then
        print("❌ Неверное количество!")
        os.sleep(2)
        return
    end
    
    -- Показываем доступные ЦП
    print("\n⚡ Доступные процессоры:")
    if meKnowledge.cpus and #meKnowledge.cpus > 0 then
        for i, cpu in ipairs(meKnowledge.cpus) do
            local status = cpu.busy and "🟡 ЗАНЯТ" or "🟢 СВОБОДЕН"
            local storageMB = string.format("%.1f", (cpu.storage or 0) / 1024)
            local cpuName = cpu.name or "ЦП #" .. i
            print(string.format("  #%d: %s - %s (%.1f МБ)", 
                cpu.index, status, cpuName, storageMB))
        end
    else
        print("  Нет данных о процессорах")
    end
    
    print("Номера ЦП (через запятую):")
    local cpuInput = io.read():gsub("^%s*(.-)%s*$", "%1")
    local preferredCPUs = {}
    for cpuStr in cpuInput:gmatch("[^,]+") do
        local cpuIndex = tonumber(cpuStr:match("%d+"))
        if cpuIndex then
            table.insert(preferredCPUs, cpuIndex)
        end
    end
    
    local maxCPUs = meKnowledge.cpus and #meKnowledge.cpus or 0
    if #preferredCPUs == 0 then
        print("❌ Не указаны ЦП!")
        os.sleep(2)
        return
    end
    
    for _, cpuIndex in ipairs(preferredCPUs) do
        if cpuIndex < 1 or cpuIndex > maxCPUs then
            print("❌ Неверный номер ЦП: " .. cpuIndex)
            os.sleep(2)
            return
        end
    end
    
    print("Использовать другие ЦП если заняты? (y/n):")
    local allowOtherInput = io.read():lower()
    local allowOtherCPUs = (allowOtherInput == "y" or allowOtherInput == "yes" or allowOtherInput == "да")
    
    print("Интервал проверки (секунды, минимум 5):")
    local timeout = tonumber(io.read())
    
    if not timeout or timeout < 5 then
        timeout = 5
        print("Установлен интервал 5 секунд")
    end
    
    -- Умный поиск крафта
    local craftableIndex = findCraftableSmart(itemID, craftName)
    
    craftDB[craftName] = {
        itemID = itemID,
        targetAmount = targetAmount,
        preferredCPUs = preferredCPUs,
        allowOtherCPUs = allowOtherCPUs,
        checkTimeout = timeout,
        craftableIndex = craftableIndex
    }
    
    if saveConfig() then
        print("\n✅ Автокрафт добавлен!")
        print("   Предмет: " .. itemLabel)
        print("   Целевое количество: " .. targetAmount)
        print("   ЦП: " .. table.concat(preferredCPUs, ", "))
        if craftableIndex then
            print("   Найден крафт: #" .. craftableIndex)
        else
            print("   ⚠️ Крафт не найден")
        end
    else
        print("❌ Ошибка сохранения")
    end
    os.sleep(3)
end

-- ПРОСМОТР БАЗЫ АВТОКРАФТОВ
local function viewCraftDB()
    if tableLength(craftDB) == 0 then
        print("База автокрафтов пуста!")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for name, data in pairs(craftDB) do
        local current = getItemCount(data.itemID)
        local status = current >= data.targetAmount and "✅" or "❌"
        local craftableInfo = data.craftableIndex and ("Крафт: #" .. data.craftableIndex) or "Крафт: не найден"
        local cpusInfo = "ЦП: " .. table.concat(data.preferredCPUs, ", ") .. (data.allowOtherCPUs and " (+другие)" or "")
        
        local craftTime = meKnowledge.craftTimes and meKnowledge.craftTimes[data.itemID]
        local timeInfo = craftTime and string.format("Время: %.1f сек", craftTime) or "Время: не измерено"
        
        local entry = string.format("%s %s\n  📦 %d/%d | ID: %s\n  %s\n  ⏰ %d сек | %s\n  %s\n%s",
            status, name, current, data.targetAmount, data.itemID, cpusInfo, 
            data.checkTimeout, timeInfo, craftableInfo, string.rep("-", 40))
        
        table.insert(dataToShow, entry)
    end
    
    showPaginated(dataToShow, "📊 БАЗА АВТОКРАФТОВ", 8)
end

-- УДАЛЕНИЕ АВТОКРАФТА
local function removeAutoCraft()
    term.clear()
    print("=== ❌ УДАЛЕНИЕ АВТОКРАФТА ===")
    
    if tableLength(craftDB) == 0 then
        print("База автокрафтов пуста!")
        os.sleep(2)
        return
    end
    
    local craftNames = {}
    for name in pairs(craftDB) do
        table.insert(craftNames, name)
    end
    
    showPaginated(craftNames, "СПИСОК АВТОКРАФТОВ", 35)
    
    print("\nВведите название для удаления:")
    local craftName = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if craftDB[craftName] then
        craftDB[craftName] = nil
        if saveConfig() then
            print("✅ Автокрафт удален!")
        else
            print("❌ Ошибка сохранения")
        end
    else
        print("❌ Автокрафт не найден!")
    end
    os.sleep(2)
end

-- БАЗА ЗНАНИЙ ME
local function showMEKnowledge()
    term.clear()
    print("=== 📚 БАЗА ЗНАНИЙ ME СИСТЕМЫ ===")
    print()
    
    local totalItems = meKnowledge.items and #meKnowledge.items or 0
    local totalCraftables = meKnowledge.craftables and #meKnowledge.craftables or 0
    local totalPatterns = tableLength(meKnowledge.patterns or {})
    local totalCPUs = meKnowledge.cpus and #meKnowledge.cpus or 0
    local totalCraftTimes = tableLength(meKnowledge.craftTimes or {})
    
    print("📊 Общая статистика:")
    print("   📦 Предметы: " .. totalItems)
    print("   🛠️ Крафты: " .. totalCraftables)
    print("   🔗 Паттерны: " .. totalPatterns)
    print("   ⚡ Процессоры: " .. totalCPUs)
    print("   ⏱️ Время крафта: " .. totalCraftTimes)
    
    print("\n" .. string.rep("=", 40))
    print("1 - Просмотр предметов")
    print("2 - Просмотр крафтов") 
    print("3 - Просмотр паттернов")
    print("4 - Просмотр процессоров")
    print("5 - Назад")
    print("\nВыберите действие:")
    
    local choice = io.read()
    
    if choice == "1" then
        local dataToShow = {}
        if meKnowledge.items then
            for i, item in ipairs(meKnowledge.items) do
                table.insert(dataToShow, string.format("  %s - %d шт. (%s)", 
                    item.name, item.size or 0, item.label or "нет"))
            end
        end
        showPaginated(dataToShow, "📦 ПРЕДМЕТЫ В СИСТЕМЕ", 35)
    elseif choice == "2" then
        local dataToShow = {}
        if meKnowledge.craftables then
            for i, craftable in ipairs(meKnowledge.craftables) do
                if craftable.itemStack then
                    table.insert(dataToShow, string.format("  #%d: %s (%s)", 
                        craftable.index, craftable.itemStack.name, craftable.itemStack.label or "нет"))
                end
            end
        end
        showPaginated(dataToShow, "🛠️ ДОСТУПНЫЕ КРАФТЫ", 35)
    elseif choice == "3" then
        local dataToShow = {}
        if meKnowledge.patterns then
            for itemID, craftableIndex in pairs(meKnowledge.patterns) do
                table.insert(dataToShow, string.format("  %s → крафт #%d", itemID, craftableIndex))
            end
        end
        showPaginated(dataToShow, "🔗 ВЫЯВЛЕННЫЕ ПАТТЕРНЫ", 35)
    elseif choice == "4" then
        local dataToShow = {}
        if meKnowledge.cpus then
            for i, cpu in ipairs(meKnowledge.cpus) do
                local status = cpu.busy and "🟡 ЗАНЯТ" or "🟢 СВОБОДЕН"
                local storageMB = string.format("%.1f", (cpu.storage or 0) / 1024)
                table.insert(dataToShow, string.format("  #%d: %s - %s (%.1f МБ)", 
                    cpu.index, status, cpu.name or "ЦП", storageMB))
            end
        end
        showPaginated(dataToShow, "⚡ ПРОЦЕССОРЫ КРАФТА", 35)
    end
end

-- ГЛАВНОЕ МЕНЮ
local function mainMenu()
    while running do
        term.clear()
        print("=== 🧠 УМНАЯ СИСТЕМА ПОДДЕРЖКИ АВТОКРАФТА ===")
        print()
        
        -- Статус системы
        local statusIcon = craftingEnabled and "🟢" or "🔴"
        print(statusIcon .. " Поддержка автокрафта: " .. (craftingEnabled and "ВКЛЮЧЕНА" or "ВЫКЛЮЧЕНА"))
        print("📊 Автокрафтов: " .. tableLength(craftDB))
        print("📚 База знаний: " .. (meKnowledge.items and #meKnowledge.items or 0) .. " предметов, " .. 
              (meKnowledge.craftables and #meKnowledge.craftables or 0) .. " крафтов")
        print("⏱️ Время крафта: " .. tableLength(meKnowledge.craftTimes or {}) .. " записей")
        
        print("\n" .. string.rep("=", 40))
        print("1. " .. (craftingEnabled and "🛑 Остановить" or "🚀 Запустить") .. " поддержку автокрафта")
        print("2. ➕ Добавить автокрафт")
        print("3. 👁️ Просмотр автокрафтов") 
        print("4. ❌ Удалить автокрафт")
        print("5. 🔍 Анализ ME системы")
        print("6. 📚 База знаний ME")
        print("7. 🗑️ Очистить все базы данных")
        print("8. 🚪 Выход")
        print("\nВыберите действие:")
        
        local choice = io.read()
        
        if choice == "1" then
            toggleAutoCraft()
        elseif choice == "2" then
            addAutoCraft()
        elseif choice == "3" then
            viewCraftDB()
        elseif choice == "4" then
            removeAutoCraft()
        elseif choice == "5" then
            analyzeMESystem()
        elseif choice == "6" then
            showMEKnowledge()
        elseif choice == "7" then
            -- Упрощенная очистка
            print("Очистка баз данных...")
            craftDB = {}
            meKnowledge = {items = {}, craftables = {}, cpus = {}, patterns = {}, craftTimes = {}}
            saveConfig()
            saveMEKnowledge()
            print("✅ Базы данных очищены")
            os.sleep(2)
        elseif choice == "8" then
            if craftingEnabled then
                craftingEnabled = false
                if craftThread then
                    craftThread:join()
                end
            end
            -- Сохраняем только основные данные перед выходом
            saveEssentialData()
            saveConfig()
            print("👋 Выход из системы...")
            break
        end
    end
end

-- ИНИЦИАЛИЗАЦИЯ СИСТЕМЫ
print("Загрузка умной системы поддержки автокрафта...")
loadConfig()
loadMEKnowledge()

-- Автоанализ только если база действительно пуста
if (not meKnowledge.items or #meKnowledge.items == 0) and running then
    print("🔄 База знаний пуста, выполняется первоначальный анализ...")
    analyzeMESystem()
else
    print("✅ Система готова к работе!")
    print("📊 Загружено автокрафтов: " .. tableLength(craftDB))
    print("📚 База знаний: " .. (meKnowledge.items and #meKnowledge.items or 0) .. " предметов")
    print("⏱️ Время крафта: " .. tableLength(meKnowledge.craftTimes or {}) .. " записей")
    os.sleep(2)
end

mainMenu()
