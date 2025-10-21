local component = require("component")
local event = require("event")
local serialization = require("serialization")
local term = require("term")
local thread = require("thread")
local computer = require("computer")

-- Конфигурация оптимизации памяти
local STORAGE_CONFIG = {
    primaryStorage = "/home/",
    externalStorage = "/mnt/raid/",
    maxMemoryItems = 5000,
    chunkSize = 50,  -- Уменьшил размер чанка
    useExternalStorage = false
}

if not component.isAvailable("me_interface") then
  print("Ошибка: ME интерфейс не найден!")
  print("Убедитесь что ME интерфейс подключен к компьютеру")
  return
end

local me = component.me_interface
local running = true
local monitoring = false
local monitorThread = nil

local craftDB = {}  
local configFile = "/home/craft_config.dat"

local meKnowledgeFile = "/home/me_knowledge.dat"
local meKnowledge = {
    items = {},          
    craftables = {},     
    cpus = {},           
    patterns = {},       
    craftTimes = {},     
    craftHistory = {},   
    researchDB = {}      
}

-- Функция подтверждения действия
local function confirmAction(actionText)
    print("\n" .. actionText .. " (y/n):")
    local input = io.read():lower()
    return (input == "y" or input == "yes" or input == "да")
end

-- Функция очистки памяти (аналог collectgarbage)
local function freeMemory()
    -- Создаем и сразу удаляем временные таблицы для освобождения памяти
    local temp = {}
    for i = 1, 50 do  -- Уменьшил количество итераций
        temp[i] = {}
        for j = 1, 5 do  -- Уменьшил вложенность
            temp[i][j] = string.rep("x", 50)
        end
    end
    temp = nil
end

-- УЛУЧШЕННАЯ функция инициализации внешнего хранилища
local function initExternalStorage()
    print("🔍 Поиск внешнего хранилища...")
    
    -- Сбрасываем состояние хранилища
    STORAGE_CONFIG.useExternalStorage = false
    STORAGE_CONFIG.externalStorage = "/mnt/raid/"
    
    -- Проверяем только реально существующие точки монтирования
    local mounts = {"/mnt/raid", "/mnt/external", "/mnt/disk", "/mnt/usb"}
    local storageFound = false
    
    for _, mount in ipairs(mounts) do
        -- Проверяем существование директории
        local checkDir = io.open(mount, "r")
        if checkDir then
            checkDir:close()
            
            -- Проверяем доступность записи
            local testFile = mount .. "/test_write.tmp"
            local testWrite = io.open(testFile, "w")
            if testWrite then
                testWrite:write("test")
                testWrite:close()
                
                -- Проверяем, что файл действительно записался
                local testRead = io.open(testFile, "r")
                if testRead then
                    local content = testRead:read("*a")
                    testRead:close()
                    os.remove(testFile)
                    
                    if content == "test" then
                        STORAGE_CONFIG.externalStorage = mount .. "/"
                        STORAGE_CONFIG.useExternalStorage = true
                        storageFound = true
                        print("✅ Внешнее хранилище найдено: " .. mount)
                        break
                    end
                end
            end
        end
    end
    
    if not storageFound then
        print("⚠️ Внешнее хранилище не найдено, используем основное")
        STORAGE_CONFIG.useExternalStorage = false
        -- Убедимся, что используем правильный путь
        STORAGE_CONFIG.externalStorage = "/home/"
    end
    
    return STORAGE_CONFIG.useExternalStorage
end

-- Функция получения пути с учетом внешнего хранилища
local function getStoragePath(filename)
    if STORAGE_CONFIG.useExternalStorage then
        return STORAGE_CONFIG.externalStorage .. filename
    else
        return STORAGE_CONFIG.primaryStorage .. filename
    end
end

-- Функция форматирования баз данных
local function formatDatabases()
    if not confirmAction("⚠️ ВНИМАНИЕ: Это действие полностью очистит все данные программы! Вы уверены?") then
        print("❌ Форматирование отменено")
        return false
    end
    
    if not confirmAction("❌ Действие необратимо! Все автокрафты, исследования и история будут удалены. Продолжить?") then
        print("❌ Форматирование отменено")
        return false
    end
    
    print("🧹 Начало форматирования баз данных...")
    
    -- Очищаем оперативную память
    craftDB = {}
    meKnowledge = {
        items = {},          
        craftables = {},     
        cpus = {},           
        patterns = {},       
        craftTimes = {},     
        craftHistory = {},   
        researchDB = {}      
    }
    
    -- Удаляем файлы конфигурации
    local filesToDelete = {
        configFile,
        meKnowledgeFile,
        getStoragePath("me_knowledge.dat"),
        STORAGE_CONFIG.primaryStorage .. "me_knowledge.dat"
    }
    
    local deletedCount = 0
    for _, filePath in ipairs(filesToDelete) do
        if os.remove(filePath) then
            print("✅ Удален: " .. filePath)
            deletedCount = deletedCount + 1
        end
    end
    
    -- Создаем чистые базы
    if saveConfig() and saveMEKnowledge() then
        print("\n✅ Форматирование завершено!")
        print("🗑️  Удалено файлов: " .. deletedCount)
        print("🆕 Созданы чистые базы данных")
        print("🔧 Система готова к настройке")
        return true
    else
        print("❌ Ошибка создания чистых баз данных")
        return false
    end
end

-- Функция оптимизации памяти
local function optimizeMemory()
    freeMemory()  -- Используем нашу функцию вместо collectgarbage
    
    if meKnowledge.craftHistory and #meKnowledge.craftHistory > 50 then  -- Уменьшил историю
        local newHistory = {}
        for i = math.max(1, #meKnowledge.craftHistory - 49), #meKnowledge.craftHistory do
            table.insert(newHistory, meKnowledge.craftHistory[i])
        end
        meKnowledge.craftHistory = newHistory
    end
end

local function tableLength(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function getTableKeys(tbl)
    if not tbl then return {} end
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

-- ОПТИМИЗИРОВАННАЯ функция загрузки
local function loadMEKnowledge()
    local paths = {
        getStoragePath("me_knowledge.dat"),
        STORAGE_CONFIG.primaryStorage .. "me_knowledge.dat"
    }
    
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            file:close()
            local success, loaded = pcall(serialization.unserialize, data)
            if success and loaded then
                meKnowledge = {
                    items = loaded.items or {},
                    craftables = loaded.craftables or {},
                    cpus = loaded.cpus or {},
                    patterns = loaded.patterns or {},
                    craftTimes = loaded.craftTimes or {},
                    craftHistory = loaded.craftHistory or {},
                    researchDB = loaded.researchDB or {}
                }
                print("📚 Загружена база знаний ME системы")
                print("   Предметы: " .. #meKnowledge.items)
                print("   Craftables: " .. #meKnowledge.craftables)
                print("   ЦП: " .. (#meKnowledge.cpus and #meKnowledge.cpus or 0))
                print("   Паттерны: " .. tableLength(meKnowledge.patterns))
                print("   Время крафта: " .. tableLength(meKnowledge.craftTimes))
                print("   История крафтов: " .. #meKnowledge.craftHistory)
                return true
            end
        end
    end
    
    print("📚 Создаем новую базу знаний ME системы")
    meKnowledge = {items = {}, craftables = {}, cpus = {}, patterns = {}, craftTimes = {}, craftHistory = {}, researchDB = {}}
    return false
end

-- СУПЕР-ОПТИМИЗИРОВАННАЯ функция сохранения
local function saveMEKnowledge()
    -- Сохраняем данные небольшими частями
    local success = false
    
    -- Пытаемся сохранить упрощенные данные
    local simpleData = {
        patterns = meKnowledge.patterns or {},
        craftTimes = meKnowledge.craftTimes or {},
        researchDB = meKnowledge.researchDB or {},
        cpus = meKnowledge.cpus or {}
    }
    
    -- Добавляем только самые необходимые данные о предметах
    simpleData.items = {}
    if meKnowledge.items then
        for i = 1, math.min(3500, #meKnowledge.items) do  -- Ограничиваем количество
            local item = meKnowledge.items[i]
            if item then
                table.insert(simpleData.items, {
                    n = item.name,    -- Сокращаем имена полей
                    s = item.size or 0,
                    l = item.label or "нет"
                })
            end
        end
    end
    
    -- Добавляем только базовую информацию о craftables
    simpleData.craftables = {}
    if meKnowledge.craftables then
        for i = 1, math.min(1500, #meKnowledge.craftables) do  -- Ограничиваем количество
            local craftable = meKnowledge.craftables[i]
            if craftable and craftable.itemStack then
                table.insert(simpleData.craftables, {
                    i = craftable.index,
                    n = craftable.itemStack.name,
                    l = craftable.itemStack.label or "нет"
                })
            end
        end
    end
    
    -- Сохраняем только последние записи истории
    simpleData.craftHistory = {}
    if meKnowledge.craftHistory then
        for i = math.max(1, #meKnowledge.craftHistory - 24), #meKnowledge.craftHistory do
            if meKnowledge.craftHistory[i] then
                local obs = meKnowledge.craftHistory[i]
                table.insert(simpleData.craftHistory, {
                    c = obs.cpuIndex,
                    d = obs.duration or 0,
                    s = obs.status or "completed"
                })
            end
        end
    end
    
    local path = getStoragePath("me_knowledge.dat")
    local file = io.open(path, "w")
    if file then
        -- Пытаемся сохранить с обработкой ошибок
        local ok, serialized = pcall(serialization.serialize, simpleData)
        if ok and serialized then
            file:write(serialized)
            file:close()
            success = true
            
            if STORAGE_CONFIG.useExternalStorage then
                local backupFile = io.open(STORAGE_CONFIG.primaryStorage .. "me_knowledge.dat", "w")
                if backupFile then
                    backupFile:write(serialized)
                    backupFile:close()
                end
            end
        else
            file:close()
            print("❌ Ошибка сериализации данных")
        end
    end
    
    return success
end

-- УПРОЩЕННАЯ функция сохранения только критически важных данных
local function saveEssentialData()
    local essentialData = {
        patterns = meKnowledge.patterns or {},
        craftTimes = meKnowledge.craftTimes or {}
    }
    
    local path = getStoragePath("me_knowledge_essential.dat")
    local file = io.open(path, "w")
    if file then
        file:write(serialization.serialize(essentialData))
        file:close()
        return true
    end
    return false
end

local function loadConfig()
    local file = io.open(configFile, "r")
    if file then
        local data = file:read("*a")
        file:close()
        local success, loaded = pcall(serialization.unserialize, data)
        if success and loaded then
            craftDB = loaded
        else
            craftDB = {}
        end
        print("Загружено автокрафтов: " .. tableLength(craftDB))
    else
        print("Конфиг не найден, создаем новую базу")
        craftDB = {}
    end
end

local function saveConfig()
    local file = io.open(configFile, "w")
    if file then
        file:write(serialization.serialize(craftDB))
        file:close()
        return true
    end
    return false
end

local function showPaginated(data, title, itemsPerPage)
    if not data or #data == 0 then
        print("   Нет данных для отображения")
        print("\nНажмите Enter для продолжения...")
        io.read()
        return
    end
    
    itemsPerPage = itemsPerPage or 20
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
                if type(data[i]) == "string" then
                    print(data[i])
                elseif title:find("ПРЕДМЕТЫ") then
                    local item = data[i]
                    print(string.format("  %s - %d шт. (label: %s)", 
                          item.name or "unknown", item.size or 0, item.label or "нет"))
                elseif title:find("CRAFTABLES") then
                    local craftable = data[i]
                    local itemName = craftable.itemStack and craftable.itemStack.name or "неизвестно"
                    local label = craftable.itemStack and craftable.itemStack.label or "нет"
                    print(string.format("  #%d: %s (label: %s)", i, itemName, label))
                elseif title:find("ЦП") then
                    local cpu = data[i]
                    local status = cpu.busy and "ЗАНЯТ" or "СВОБОДЕН"
                    print(string.format("  #%d: %s (%d КБ)", i, status, cpu.storage or 0))
                else
                    print("  " .. tostring(data[i]))
                end
            end
        end
        
        print("\nНавигация:")
        if currentPage > 1 then
            print("P - Предыдущая страница")
        end
        if currentPage < totalPages then
            print("N - Следующая страница")
        end
        print("E - Выход в меню")
        
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

-- СУПЕР-ОПТИМИЗИРОВАННАЯ функция анализа ME системы
local function analyzeMESystem()
    if not confirmAction("Вы уверены, что хотите выполнить анализ ME системы? Это может занять некоторое время.") then
        print("❌ Анализ отменен")
        return
    end
    
    print("🔍 Анализ ME системы...")
    initExternalStorage()
    
    -- ОЧИСТКА ДАННЫХ ПЕРЕД НОВЫМ АНАЛИЗОМ
    meKnowledge.items = {}
    meKnowledge.craftables = {}
    meKnowledge.patterns = {}
    
    if not meKnowledge.cpus then meKnowledge.cpus = {} end
    if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
    if not meKnowledge.craftHistory then meKnowledge.craftHistory = {} end
    if not meKnowledge.researchDB then meKnowledge.researchDB = {} end
    
    -- Анализ предметов по чанкам с промежуточным сохранением
    local success, items = pcall(me.getItemsInNetwork)
    if success and items then
        meKnowledge.items = {}
        local itemCount = #items
        print("   📦 Всего предметов: " .. itemCount)
        
        -- Обрабатываем предметы маленькими чанками
        for chunkStart = 1, itemCount, STORAGE_CONFIG.chunkSize do
            local chunkEnd = math.min(chunkStart + STORAGE_CONFIG.chunkSize - 1, itemCount)
            print("   Обработка предметов: " .. chunkStart .. "-" .. chunkEnd)
            
            for i = chunkStart, chunkEnd do
                local item = items[i]
                if item and item.name then
                    table.insert(meKnowledge.items, {
                        name = item.name,
                        size = item.size or 0,
                        label = item.label or "нет"
                    })
                end
                
                -- Частая разгрузка памяти
                if i % 10 == 0 then
                    freeMemory()
                    os.sleep(0.1)
                end
            end
            
            -- Сохраняем только паттерны и основные данные каждые 50 предметов
            if chunkEnd % 50 == 0 then
                saveEssentialData()
                freeMemory()
            end
        end
        print("   ✅ Предметов анализировано: " .. #meKnowledge.items)
    else
        print("   ❌ Ошибка анализа предметов")
    end
    
    -- ОПТИМИЗИРОВАННЫЙ анализ craftables с ЧРЕЗВЫЧАЙНОЙ экономией памяти
    print("   🛠️ Анализ craftables...")
    local success, craftables = pcall(me.getCraftables)
    if success and craftables then
        meKnowledge.craftables = {}
        local craftableCount = #craftables
        print("   📋 Всего craftables: " .. craftableCount)
        
        local processed = 0
        local saveCounter = 0
        
        -- Обрабатываем очень маленькими чанками
        for chunkStart = 1, craftableCount, 25 do  -- Уменьшил размер чанка
            local chunkEnd = math.min(chunkStart + 24, craftableCount)
            
            for i = chunkStart, chunkEnd do
                local craftable = craftables[i]
                if craftable then
                    local craftableInfo = {
                        index = i,
                        itemStack = {}
                    }
                    
                    -- Получаем только самую необходимую информацию
                    if craftable.getItemStack then
                        local itemSuccess, itemStack = pcall(craftable.getItemStack)
                        if itemSuccess and itemStack and itemStack.name then
                            craftableInfo.itemStack = {
                                name = itemStack.name,
                                label = itemStack.label or "нет"
                            }
                            
                            -- Сохраняем только паттерн (самое важное)
                            meKnowledge.patterns[itemStack.name] = i
                        end
                    end
                    
                    table.insert(meKnowledge.craftables, craftableInfo)
                    processed = processed + 1
                    
                    -- Выводим прогресс каждые 10 craftables
                    if processed % 10 == 0 then
                        print("   Обработано: " .. processed .. "/" .. craftableCount)
                    end
                end
                
                -- Очень частая разгрузка памяти
                if i % 5 == 0 then
                    freeMemory()
                    os.sleep(0.2)  -- Увеличил задержку для стабильности
                end
            end
            
            -- Сохраняем ТОЛЬКО паттерны каждые 25 craftables
            saveCounter = saveCounter + 1
            if saveCounter % 4 == 0 then  -- Каждые 100 craftables
                print("   💾 Сохранение паттернов...")
                saveEssentialData()
                freeMemory()
            end
        end
        print("   ✅ Craftables анализировано: " .. #meKnowledge.craftables)
    else
        print("   ❌ Ошибка анализа craftables")
    end
    
    -- Анализ ЦП
    print("   ⚡ Анализ ЦП...")
    local success, cpus = pcall(me.getCraftingCPUs)
    if success and cpus then
        meKnowledge.cpus = {}
        for i, cpu in ipairs(cpus) do
            if cpu then
                table.insert(meKnowledge.cpus, {
                    index = i,
                    busy = cpu.busy or false,
                    storage = cpu.storage or 0,
                    name = cpu.name or "Без названия"
                })
            end
        end
        print("   ✅ ЦП анализировано: " .. #meKnowledge.cpus)
    else
        print("   ❌ Ошибка анализа ЦП")
    end
    
    -- Финальное сохранение только самых важных данных
    freeMemory()
    if saveEssentialData() then
        print("✅ Анализ ME системы завершен! (сохранены только паттерны)")
    else
        print("❌ Ошибка сохранения базы знаний")
    end
end

-- ОПТИМИЗИРОВАННАЯ функция исследования всех крафтов
local function researchAllCrafts()
    if not confirmAction("Вы уверены, что хотите исследовать все крафты? Это может занять много времени.") then
        print("❌ Исследование отменен")
        return
    end
    
    print("🔬 Интеллектуальное исследование всех крафтов...")
    
    local success, craftables = pcall(me.getCraftables)
    if not success or not craftables then
        print("❌ Не удалось получить список craftables")
        return
    end
    
    local researched = 0
    local tempResearchDB = {}
    local craftableCount = #craftables
    
    print("   📋 Всего craftables для исследования: " .. craftableCount)
    
    -- Исследуем craftables очень маленькими чанками
    for chunkStart = 1, craftableCount, 20 do
        local chunkEnd = math.min(chunkStart + 19, craftableCount)
        
        for i = chunkStart, chunkEnd do
            local craftable = craftables[i]
            if craftable and craftable.getItemStack then
                local itemSuccess, itemStack = pcall(craftable.getItemStack)
                if itemSuccess and itemStack and itemStack.name then
                    table.insert(tempResearchDB, {
                        craftableIndex = i,
                        itemID = itemStack.name,
                        label = itemStack.label or "Без названия"
                    })
                    
                    researched = researched + 1
                    meKnowledge.patterns[itemStack.name] = i
                    
                    if researched % 25 == 0 then
                        print("   ✅ Исследовано: " .. researched .. " крафтов")
                        -- Сохраняем только паттерны
                        saveEssentialData()
                        freeMemory()
                    end
                end
            end
            
            -- Частая разгрузка памяти
            if i % 5 == 0 then
                freeMemory()
                os.sleep(0.1)
            end
        end
    end
    
    meKnowledge.researchDB = tempResearchDB
    freeMemory()
    
    if saveEssentialData() then
        print("✅ Исследование завершено! Найдено крафтов: " .. researched)
    else
        print("❌ Ошибка сохранения исследований")
    end
    return tempResearchDB
end

-- Остальные функции остаются без изменений (showResearchDB, getItemCount, и т.д.)
local function showResearchDB()
    if not meKnowledge.researchDB or #meKnowledge.researchDB == 0 then
        print("❌ База исследований пуста! Сначала выполните исследование.")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for i, research in ipairs(meKnowledge.researchDB) do
        table.insert(dataToShow, string.format("Craftable #%d: %s (ID: %s)", 
            research.craftableIndex, research.label, research.itemID))
    end
    
    showPaginated(dataToShow, "🔬 БАЗА ИССЛЕДОВАНИЙ КРАФТОВ", 15)
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

local function getItemInfo(itemID)
    if not meKnowledge.items then return nil end
    for i, item in ipairs(meKnowledge.items) do
        if item.name == itemID then
            return item
        end
    end
    return nil
end

-- ОБНОВЛЕННАЯ функция измерения времени крафта с подтверждением
local function measureCraftTime(itemID, craftName, craftableIndex)
    if not confirmAction("Измерение времени крафта создаст 3 предмета. Продолжить?") then
        print("❌ Измерение отменено")
        return nil
    end
    
    print("⏱️ Измерение времени крафта для: " .. craftName)
    
    local success, craftables = pcall(me.getCraftables)
    if not success or not craftables or not craftables[craftableIndex] then
        print("❌ Craftable не найден для измерения времени")
        return nil
    end
    
    local craftable = craftables[craftableIndex]
    local totalTime = 0
    local successfulMeasurements = 0
    
    for attempt = 1, 3 do
        print("   Попытка " .. attempt .. "/3...")
        
        local startCount = getItemCount(itemID)
        local startTime = computer.uptime()
        
        local craftSuccess, result = pcall(craftable.request, 1)
        
        if craftSuccess and result then
            local timeout = 30
            local craftCompleted = false
            
            for i = 1, timeout do
                os.sleep(1)
                local currentCount = getItemCount(itemID)
                
                if currentCount > startCount then
                    local endTime = computer.uptime()
                    local craftTime = endTime - startTime
                    totalTime = totalTime + craftTime
                    successfulMeasurements = successfulMeasurements + 1
                    craftCompleted = true
                    print("     ✅ Крафт завершен за " .. string.format("%.1f", craftTime) .. " сек")
                    break
                end
            end
            
            if not craftCompleted then
                print("     ❌ Таймаут измерения попытки " .. attempt)
            end
        else
            print("     ❌ Ошибка заказа крафта")
        end
        
        os.sleep(2) 
    end
    
    if successfulMeasurements > 0 then
        local averageTime = totalTime / successfulMeasurements
        meKnowledge.craftTimes[itemID] = averageTime
        if saveEssentialData() then
            print("   📊 Среднее время крафта: " .. string.format("%.1f", averageTime) .. " сек")
        else
            print("   ❌ Ошибка сохранения времени крафта")
        end
        return averageTime
    else
        print("   ❌ Не удалось измерить время крафта")
        return nil
    end
end

local function showCraftTimes()
    if not meKnowledge.craftTimes or tableLength(meKnowledge.craftTimes) == 0 then
        print("❌ Нет данных о времени крафта")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for itemID, time in pairs(meKnowledge.craftTimes) do
        local label = itemID
        local itemInfo = getItemInfo(itemID)
        if itemInfo and itemInfo.label then
            label = itemInfo.label
        end
        
        table.insert(dataToShow, string.format("%s: %.1f сек", label, time))
    end
    
    showPaginated(dataToShow, "⏱️ БАЗА ВРЕМЕНИ КРАФТА", 15)
end

-- УЛУЧШЕННАЯ функция мониторинга активных крафтов
local function monitorActiveCrafts()
    print("🎯 Запуск мониторинга активных крафтов...")
    
    local lastCpuState = {}
    local currentObservations = {}
    
    if meKnowledge.cpus then
        for i, cpu in ipairs(meKnowledge.cpus) do
            lastCpuState[i] = {busy = cpu.busy or false, name = cpu.name or "Без названия"}
        end
    end
    
    while monitoring do
        local success, cpus = pcall(me.getCraftingCPUs)
        if success and cpus then
            for i, cpu in ipairs(cpus) do
                if cpu then
                    local currentBusy = cpu.busy or false
                    local lastBusy = lastCpuState[i] and lastCpuState[i].busy or false
                    
                    if currentBusy and not lastBusy then
                        print("🔍 Обнаружен новый крафт на ЦП #" .. i .. " (" .. (cpu.name or "Без названия") .. ")")
                        
                        local observation = {
                            cpuIndex = i,
                            cpuName = cpu.name or "Без названия",
                            startTime = computer.uptime(),
                            startItems = {},
                            status = "active"
                        }
                        
                        -- Сохраняем состояние предметов на начало крафта
                        if meKnowledge.items then
                            for _, item in ipairs(meKnowledge.items) do
                                observation.startItems[item.name] = item.size or 0
                            end
                        end
                        
                        currentObservations[i] = observation
                        
                    elseif not currentBusy and lastBusy and currentObservations[i] then
                        local observation = currentObservations[i]
                        observation.endTime = computer.uptime()
                        observation.duration = observation.endTime - observation.startTime
                        observation.status = "completed"
                        
                        -- Обновляем информацию о предметах
                        updateItemCounts()
                        
                        -- Определяем какие предметы были скрафчены
                        local craftedItems = {}
                        if meKnowledge.items then
                            for _, item in ipairs(meKnowledge.items) do
                                local startCount = observation.startItems[item.name] or 0
                                local endCount = item.size or 0
                                if endCount > startCount then
                                    table.insert(craftedItems, {
                                        itemID = item.name,
                                        itemLabel = item.label or item.name,
                                        amount = endCount - startCount
                                    })
                                    
                                    -- Обновляем время крафта для этого предмета
                                    meKnowledge.craftTimes[item.name] = observation.duration
                                    print("   💾 Обновлено время крафта для " .. (item.label or item.name) .. ": " .. string.format("%.1f", observation.duration) .. " сек")
                                end
                            end
                        end
                        
                        observation.craftedItems = craftedItems
                        
                        if not meKnowledge.craftHistory then
                            meKnowledge.craftHistory = {}
                        end
                        table.insert(meKnowledge.craftHistory, observation)
                        
                        saveEssentialData()
                        
                        print("✅ Завершен крафт на ЦП #" .. i .. ", длительность: " .. string.format("%.1f", observation.duration) .. " сек")
                        if #craftedItems > 0 then
                            print("   📦 Скрафчено предметов: " .. #craftedItems)
                            for j, item in ipairs(craftedItems) do
                                if j <= 3 then
                                    print("     - " .. item.itemLabel .. " x" .. item.amount)
                                end
                            end
                            if #craftedItems > 3 then
                                print("     ... и еще " .. (#craftedItems - 3) .. " предметов")
                            end
                        end
                        currentObservations[i] = nil
                    end
                    
                    lastCpuState[i] = {busy = currentBusy, name = cpu.name or "Без названия"}
                end
            end
        end
        
        os.sleep(2) 
    end
end

-- ОБНОВЛЕННАЯ функция переключения мониторинга с подтверждением
local function toggleCraftMonitoring()
    if monitoring then
        if not confirmAction("Вы уверены, что хотите остановить мониторинг крафтов?") then
            return
        end
        monitoring = false
        if monitorThread then
            monitorThread:join()
            monitorThread = nil
        end
        print("🛑 Мониторинг крафтов остановлен")
    else
        if not confirmAction("Запустить мониторинг крафтов?") then
            return
        end
        monitoring = true
        monitorThread = thread.create(monitorActiveCrafts)
        print("🎯 Мониторинг крафтов запущен")
    end
    os.sleep(2)
end

local function showMonitoringStatus()
    term.clear()
    print("=== 🎯 СТАТУС МОНИТОРИНГА КРАФТОВ ===")
    
    if monitoring then
        print("📊 Статус: 🟢 АКТИВЕН")
        print("👁️  Наблюдение за активными крафтами...")
    else
        print("📊 Статус: 🔴 ВЫКЛЮЧЕН")
    end
    
    print("\n⚡ АКТИВНЫЕ ЦП:")
    local success, cpus = pcall(me.getCraftingCPUs)
    local activeCount = 0
    if success and cpus then
        for i, cpu in ipairs(cpus) do
            if cpu and cpu.busy then
                print("   ЦП #" .. i .. ": 🟡 ЗАНЯТ - " .. (cpu.name or "Без названия"))
                activeCount = activeCount + 1
            end
        end
    end
    if activeCount == 0 then
        print("   Нет активных крафтов")
    end
    
    print("\n📋 ПОСЛЕДНИЕ НАБЛЮДЕНИЯ:")
    local recentObservations = {}
    if meKnowledge.craftHistory then
        for i = #meKnowledge.craftHistory, math.max(1, #meKnowledge.craftHistory - 4), -1 do
            table.insert(recentObservations, meKnowledge.craftHistory[i])
        end
    end
    
    if #recentObservations == 0 then
        print("   Нет данных о прошлых крафтах")
    else
        for i, obs in ipairs(recentObservations) do
            print("   " .. i .. ". ЦП #" .. obs.cpuIndex .. " (" .. (obs.cpuName or "Без названия") .. ")")
            print("      Время: " .. string.format("%.1f", obs.duration or 0) .. " сек")
            if obs.craftedItems and #obs.craftedItems > 0 then
                for j, item in ipairs(obs.craftedItems) do
                    if j <= 2 then 
                        print("      📦 " .. (item.itemLabel or item.itemID) .. " x" .. item.amount)
                    end
                end
                if #obs.craftedItems > 2 then
                    print("      ... и еще " .. (#obs.craftedItems - 2) .. " предметов")
                end
            end
            print("      ---")
        end
    end
    
    print("\n📊 Всего записей в истории: " .. (meKnowledge.craftHistory and #meKnowledge.craftHistory or 0))
    print("\nНажмите Enter для продолжения...")
    io.read()
end

-- Умный поиск craftable по данным анализа (без физического крафта)
local function findCraftableSmart(itemID, itemName)
    print("🔍 Умный поиск craftable для: " .. itemName)
    
    -- Проверяем выявленные паттерны
    if meKnowledge.patterns and meKnowledge.patterns[itemID] then
        local craftableIndex = meKnowledge.patterns[itemID]
        print("   ✅ Найден в паттернах: craftable #" .. craftableIndex)
        return craftableIndex
    end
    
    -- Ищем через анализ itemStack в craftables
    if meKnowledge.craftables then
        for i, craftableInfo in ipairs(meKnowledge.craftables) do
            if craftableInfo.itemStack and craftableInfo.itemStack.name == itemID then
                print("   ✅ Найден через itemStack: craftable #" .. i)
                meKnowledge.patterns[itemID] = i
                saveEssentialData()
                return i
            end
        end
    end
    
    -- Ищем по совпадению label или имени
    if meKnowledge.craftables then
        for i, craftableInfo in ipairs(meKnowledge.craftables) do
            if craftableInfo.itemStack then
                local stack = craftableInfo.itemStack
                if stack.label and stack.label:lower():find(itemName:lower(), 1, true) then
                    print("   ✅ Найден по совпадению label: craftable #" .. i)
                    meKnowledge.patterns[itemID] = i
                    saveEssentialData()
                    return i
                end
            end
        end
    end
    
    print("   ❌ Craftable не найден в базе знаний")
    return nil
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

-- НОВАЯ функция для получения доступного ЦП
local function getAvailableCPU(preferredCPUs, allowOtherCPUs)
    local success, cpus = pcall(me.getCraftingCPUs)
    if not success or not cpus then
        return nil
    end
    
    -- Сначала ищем среди предпочтительных ЦП
    for _, cpuIndex in ipairs(preferredCPUs) do
        if cpus[cpuIndex] and not cpus[cpuIndex].busy then
            return cpuIndex
        end
    end
    
    -- Если разрешено использовать другие ЦП
    if allowOtherCPUs then
        for i, cpu in ipairs(cpus) do
            if cpu and not cpu.busy then
                -- Проверяем, что этот ЦП не в списке предпочтительных (уже проверены)
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

-- ОБНОВЛЕННАЯ функция запроса крафта с поддержкой нескольких ЦП
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
            print("❌ Не удалось найти craftable для " .. craftName)
            return false
        end
    end
    
    local success, craftables = pcall(me.getCraftables)
    if not success or not craftables or not craftables[craftableIndex] then
        print("❌ Craftable не найден: #" .. craftableIndex)
        return false
    end
    
    local craftable = craftables[craftableIndex]
    local craftSuccess, result = pcall(craftable.request, amount)
    
    if craftSuccess then
        if result then
            print("✅ Крафт заказан: " .. craftName .. " x" .. amount)
            return true
        else
            print("❌ Крафт вернул false: " .. craftName)
            return false
        end
    else
        print("❌ Ошибка при заказе крафта: " .. tostring(result))
        return false
    end
end

local function waitForCraft(itemID, targetAmount, craftName)
    print("⏳ Ожидание крафта " .. craftName .. "...")
    
    local averageTime = meKnowledge.craftTimes and meKnowledge.craftTimes[itemID]
    local timeout = averageTime and (averageTime * 2 + 60) or 300
    local startTime = computer.uptime()
    
    if averageTime then
        print("   📊 Ожидаемое время: ~" .. string.format("%.1f", averageTime) .. " сек")
    end
    
    while computer.uptime() - startTime < timeout do
        updateItemCounts()  
        local currentCount = getItemCount(itemID)
        local elapsed = math.floor(computer.uptime() - startTime)
        print("   Прогресс: " .. currentCount .. "/" .. targetAmount .. " (" .. elapsed .. "с)")
        
        if currentCount >= targetAmount then
            print("✅ Крафт завершен! " .. craftName)
            
            if not meKnowledge.craftTimes or not meKnowledge.craftTimes[itemID] then
                local actualTime = computer.uptime() - startTime
                if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
                meKnowledge.craftTimes[itemID] = actualTime
                saveEssentialData()
                print("   💾 Сохранено время крафта: " .. string.format("%.1f", actualTime) .. " сек")
            end
            
            return true
        end
        
        os.sleep(5)
    end
    
    print("❌ Таймаут ожидания крафта!")
    return false
end

-- ОБНОВЛЕННАЯ функция основного цикла крафта с подтверждением
local function craftLoop()
    if not confirmAction("Запустить автокрафт?") then
        print("❌ Запуск отменен")
        return
    end
    
    print("🚀 Запуск умного автокрафта...")
    
    while running do
        for name, craftData in pairs(craftDB) do
            if not running then break end
            
            print("\n🔍 Проверка: " .. name)
            updateItemCounts()
            local currentCount = getItemCount(craftData.itemID)
            print("📦 Количество: " .. currentCount .. "/" .. craftData.targetAmount)
            
            if currentCount < craftData.targetAmount then
                local needed = craftData.targetAmount - currentCount
                print("🛠️ Необходимо крафтить: " .. needed .. " шт.")
                
                -- Получаем доступный ЦП
                local availableCPU = getAvailableCPU(craftData.preferredCPUs, craftData.allowOtherCPUs)
                
                if availableCPU then
                    print("⚡ Используется ЦП #" .. availableCPU)
                    if requestCraft(craftData.itemID, needed, craftData.preferredCPUs, craftData.allowOtherCPUs, name) then
                        waitForCraft(craftData.itemID, craftData.targetAmount, name)
                    else
                        print("❌ Не удалось заказать крафт")
                    end
                else
                    print("⏳ Все указанные ЦП заняты, ожидание...")
                    os.sleep(10)
                end
            else
                print("✅ Достаточное количество")
            end
            
            print("⏰ Ожидание " .. craftData.checkTimeout .. " сек...")
            os.sleep(craftData.checkTimeout)
        end
        
        if running then
            print("\n--- 🔄 Цикл завершен ---")
            os.sleep(10)
        end
    end
end

local function showMEKnowledge()
    term.clear()
    print("=== 📚 БАЗА ЗНАНИЙ ME СИСТЕМЫ ===")
    
    print("\n📦 ПРЕДМЕТЫ В СИСТЕМЕ (" .. (meKnowledge.items and #meKnowledge.items or 0) .. "):")
    showPaginated(meKnowledge.items or {}, "📦 ПРЕДМЕТЫ В СИСТЕМЕ", 15)
    
    print("\n🛠️ CRAFTABLES (" .. (meKnowledge.craftables and #meKnowledge.craftables or 0) .. "):")
    showPaginated(meKnowledge.craftables or {}, "🛠️ CRAFTABLES", 15)
    
    print("\n🔗 ВЫЯВЛЕННЫЕ ПАТТЕРНЫ:")
    local patternsList = {}
    if meKnowledge.patterns then
        for itemID, craftableIndex in pairs(meKnowledge.patterns) do
            table.insert(patternsList, "  " .. itemID .. " -> craftable #" .. craftableIndex)
        end
    end
    showPaginated(patternsList, "🔗 ВЫЯВЛЕННЫЕ ПАТТЕРНЫ", 15)
    
    print("\n⚡ ЦП (" .. (meKnowledge.cpus and #meKnowledge.cpus or 0) .. "):")
    showPaginated(meKnowledge.cpus or {}, "⚡ ЦП", 10)
    
    print("\nНажмите Enter для продолжения...")
    io.read()
end

local function showCraftableDetails()
    if not meKnowledge.craftables or #meKnowledge.craftables == 0 then
        print("Нет данных о craftables")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    
    for i, craftable in ipairs(meKnowledge.craftables) do
        local craftableText = "\nCraftable #" .. i .. ":\n"
        
        if craftable.itemStack then
            craftableText = craftableText .. "  ItemStack:\n"
            craftableText = craftableText .. "    ID: " .. (craftable.itemStack.name or "нет") .. "\n"
            craftableText = craftableText .. "    Label: " .. (craftable.itemStack.label or "нет") .. "\n"
            craftableText = craftableText .. "    Size: " .. (craftable.itemStack.size or "нет") .. "\n"
        end
        
        craftableText = craftableText .. "  Методы: " .. table.concat(getTableKeys(craftable.methods or {}), ", ") .. "\n"
        
        if craftable.fields and next(craftable.fields) ~= nil then
            craftableText = craftableText .. "  Поля:\n"
            for key, value in pairs(craftable.fields) do
                craftableText = craftableText .. "    " .. key .. ": " .. tostring(value) .. "\n"
            end
        end
        
        table.insert(dataToShow, craftableText)
    end
    
    showPaginated(dataToShow, "🔍 ДЕТАЛЬНЫЙ АНАЛИЗ CRAFTABLE", 3)
end

local function showAvailableCPUs()
    print("\n=== ⚡ ДОСТУПНЫЕ ЦП ===")
    if not meKnowledge.cpus or #meKnowledge.cpus == 0 then
        print("   Нет данных о ЦП")
        return
    end
    
    for i, cpu in ipairs(meKnowledge.cpus) do
        local status = cpu.busy and "🟡 ЗАНЯТ" or "🟢 СВОБОДЕН"
        local storageMB = string.format("%.1f", (cpu.storage or 0) / 1024)
        
        print("ЦП #" .. i .. ":")
        print("  Статус: " .. status)
        print("  Память: " .. storageMB .. " МБ (" .. (cpu.storage or 0) .. " КБ)")
        print("  Название: " .. (cpu.name or "Без названия"))
    end
end

-- ОБНОВЛЕННАЯ функция добавления автокрафта с подтверждением
local function addAutoCraft()
    term.clear()
    print("=== ➕ ДОБАВЛЕНИЕ АВТОКРАФТА ===")
    
    showAvailableCPUs()
    print()
    
    print("📦 ПОСЛЕДНИЕ 15 ПРЕДМЕТОВ В СИСТЕМЕ:")
    local recentItems = {}
    if meKnowledge.items and #meKnowledge.items > 0 then
        local startIndex = math.max(1, #meKnowledge.items - 14)
        for i = startIndex, #meKnowledge.items do
            if meKnowledge.items[i] then
                local item = meKnowledge.items[i]
                print("  " .. item.name .. " - " .. (item.size or 0) .. " шт. (" .. (item.label or "нет") .. ")")
                table.insert(recentItems, item)
            end
        end
    else
        print("  Нет предметов для отображения")
    end
    
    print("\nВведите название автокрафта:")
    local craftName = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if craftDB[craftName] then
        print("Ошибка: автокрафт с таким именем уже существует!")
        os.sleep(3)
        return
    end
    
    print("Введите ID предмета (см. список выше):")
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
        print("Ошибка: предмет " .. itemID .. " не найден в ME системе!")
        os.sleep(3)
        return
    end
    
    print("Введите количество для поддержания:")
    local targetAmount = tonumber(io.read())
    
    if not targetAmount or targetAmount <= 0 then
        print("Ошибка: неверное количество!")
        os.sleep(2)
        return
    end
    
    print("Введите номера ЦП для обработки (через запятую, например: 1,2,3):")
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
        print("Ошибка: не указаны номера ЦП!")
        os.sleep(2)
        return
    end
    
    for _, cpuIndex in ipairs(preferredCPUs) do
        if cpuIndex < 1 or cpuIndex > maxCPUs then
            print("Ошибка: неверный номер ЦП " .. cpuIndex .. "! Доступны: 1-" .. maxCPUs)
            os.sleep(2)
            return
        end
    end
    
    print("Разрешить использование других ЦП если все указанные заняты? (y/n):")
    local allowOtherInput = io.read():lower()
    local allowOtherCPUs = (allowOtherInput == "y" or allowOtherInput == "yes" or allowOtherInput == "да")
    
    print("Введите таймаут проверки (в секундах, минимум 5):")
    local timeout = tonumber(io.read())
    
    if not timeout or timeout < 5 then
        timeout = 5
        print("Таймаут установлен на минимум 5 секунд")
    end
    
    local craftableIndex = findCraftableSmart(itemID, craftName)
    
    craftDB[craftName] = {
        itemID = itemID,
        targetAmount = targetAmount,
        preferredCPUs = preferredCPUs,
        allowOtherCPUs = allowOtherCPUs,
        checkTimeout = timeout,
        craftableIndex = craftableIndex
    }
    
    print("Измерить среднее время крафта? (y/n):")
    local measure = io.read():lower()
    if measure == "y" and craftableIndex then
        measureCraftTime(itemID, craftName, craftableIndex)
    end
    
    if saveConfig() then
        print("✅ Автокрафт '" .. craftName .. "' успешно добавлен!")
        print("   Предмет: " .. itemLabel)
        print("   Предпочтительные ЦП: " .. table.concat(preferredCPUs, ", "))
        print("   Использование других ЦП: " .. (allowOtherCPUs and "ВКЛ" or "ВЫКЛ"))
        if craftableIndex then
            print("   Craftable: #" .. craftableIndex)
        else
            print("   ⚠️ Craftable не найден, потребуется ручная настройка")
        end
    else
        print("❌ Ошибка сохранения автокрафта")
    end
    os.sleep(3)
end

local function viewCraftDB()
    if tableLength(craftDB) == 0 then
        print("База пуста!")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for name, data in pairs(craftDB) do
        local current = getItemCount(data.itemID)
        local status = current >= data.targetAmount and "✅" or "❌"
        local craftableInfo = data.craftableIndex and ("Craftable: #" .. data.craftableIndex) or "Craftable: не найден"
        local cpusInfo = "ЦП: " .. table.concat(data.preferredCPUs, ", ") .. (data.allowOtherCPUs and " (+другие)" or "")
        
        local craftTime = meKnowledge.craftTimes and meKnowledge.craftTimes[data.itemID]
        local timeInfo = craftTime and string.format("Время крафта: %.1f сек", craftTime) or "Время крафта: не измерено"
        
        local entry = string.format("%s %s: %d/%d\n  ID: %s\n  %s\n  Таймаут: %d сек\n  %s\n  %s\n---",
            status, name, current, data.targetAmount, data.itemID, cpusInfo, 
            data.checkTimeout, craftableInfo, timeInfo)
        
        table.insert(dataToShow, entry)
    end
    
    showPaginated(dataToShow, "📊 БАЗА АВТОКРАФТОВ", 5)
end

-- ОБНОВЛЕННАЯ функция удаления автокрафта с подтверждением
local function removeAutoCraft()
    term.clear()
    print("=== ❌ УДАЛЕНИЕ АВТОКРАФТА ===")
    
    if tableLength(craftDB) == 0 then
        print("База пуста!")
        os.sleep(2)
        return
    end
    
    local craftNames = {}
    for name in pairs(craftDB) do
        table.insert(craftNames, name)
    end
    
    showPaginated(craftNames, "СПИСОК АВТОКРАФТОВ", 20)
    
    print("\nВведите название для удаления:")
    local craftName = io.read():gsub("^%s*(.-)%s*$", "%1")
    
    if craftDB[craftName] then
        if not confirmAction("Вы уверены, что хотите удалить автокрафт '" .. craftName .. "'?") then
            print("❌ Удаление отменено")
            os.sleep(2)
            return
        end
        
        craftDB[craftName] = nil
        if saveConfig() then
            print("✅ Удалено!")
        else
            print("❌ Ошибка сохранения изменений")
        end
    else
        print("❌ Не найдено!")
    end
    os.sleep(2)
end

-- ОБНОВЛЕННАЯ функция оптимизации памяти с подтверждением
local function optimizeMemoryWithConfirm()
    if not confirmAction("Вы уверены, что хотите оптимизировать память? Будут удалены старые записи истории.") then
        print("❌ Оптимизация отменена")
        return
    end
    
    optimizeMemory()
    if saveEssentialData() then
        print("✅ Память оптимизирована!")
    else
        print("❌ Ошибка сохранения")
    end
    os.sleep(1)
end

local function mainMenu()
    local craftThread = nil
    
    while running do
        term.clear()
        print("=== 🧠 УМНАЯ СИСТЕМА АВТОКРАФТА ===")
        print("📊 Автокрафтов: " .. tableLength(craftDB))
        print("📚 Знаний ME: " .. (meKnowledge.items and #meKnowledge.items or 0) .. " предметов, " .. 
              (meKnowledge.craftables and #meKnowledge.craftables or 0) .. " craftables")
        print("⚡ ЦП: " .. (meKnowledge.cpus and #meKnowledge.cpus or 0))
        print("⏱️ Время крафта: " .. tableLength(meKnowledge.craftTimes or {}))
        print("📋 История крафтов: " .. (meKnowledge.craftHistory and #meKnowledge.craftHistory or 0))
        print("🎯 Мониторинг: " .. (monitoring and "🟢 ВКЛ" or "🔴 ВЫКЛ"))
        print("💾 Хранилище: " .. (STORAGE_CONFIG.useExternalStorage and "🟢 ВНЕШНЕЕ" or "🔴 ЛОКАЛЬНОЕ"))
        print()
        print("1 - 🚀 Запуск автокрафта")
        print("2 - 🛑 Остановка автокрафта")
        print("3 - ➕ Добавить автокрафт")
        print("4 - 👁️ Просмотр автокрафтов")
        print("5 - ❌ Удалить автокрафт")
        print("6 - 🔍 Анализ ME системы")
        print("7 - 📚 Просмотр базы знаний ME")
        print("8 - 🔎 Детали craftables")
        print("9 - 🧹 Обновить данные ME")
        print("10 - 🔬 Исследовать все крафты")
        print("11 - 📋 Просмотр исследований")
        print("12 - ⏱️ Просмотр времени крафта")
        print("13 - 🎯 Мониторинг крафтов")
        print("14 - 📊 Статус мониторинга")
        print("15 - 🧹 Оптимизировать память")
        print("16 - 🗑️  Форматировать базы данных")
        print("17 - 🚪 Выход")
        print()
        print("Выберите действие:")
        
        local choice = io.read()
        
        if choice == "1" and not craftThread then
            if tableLength(craftDB) == 0 then
                print("❌ Нет автокрафтов в базе!")
                os.sleep(2)
            else
                craftThread = thread.create(craftLoop)
                print("✅ Автокрафт запущен!")
                os.sleep(1)
            end
        elseif choice == "2" and craftThread then
            if not confirmAction("Вы уверены, что хотите остановить автокрафт?") then
                print("❌ Остановка отменена")
                os.sleep(1)
            else
                running = false
                craftThread:join()
                craftThread = nil
                running = true
                print("✅ Автокрафт остановлен!")
                os.sleep(1)
            end
        elseif choice == "3" then
            addAutoCraft()
        elseif choice == "4" then
            viewCraftDB()
        elseif choice == "5" then
            removeAutoCraft()
        elseif choice == "6" then
            analyzeMESystem()
            print("\nНажмите Enter...")
            io.read()
        elseif choice == "7" then
            showMEKnowledge()
        elseif choice == "8" then
            showCraftableDetails()
        elseif choice == "9" then
            if not confirmAction("Обновить данные ME системы? Существующие данные будут очищены.") then
                print("❌ Обновление отменено")
                os.sleep(1)
            else
                analyzeMESystem()
                print("✅ Данные обновлены!")
                os.sleep(2)
            end
        elseif choice == "10" then
            researchAllCrafts()
            print("\nНажмите Enter...")
            io.read()
        elseif choice == "11" then
            showResearchDB()
        elseif choice == "12" then
            showCraftTimes()
        elseif choice == "13" then
            toggleCraftMonitoring()
        elseif choice == "14" then
            showMonitoringStatus()
        elseif choice == "15" then
            optimizeMemoryWithConfirm()
        elseif choice == "16" then
            formatDatabases()
            print("\nНажмите Enter...")
            io.read()
        elseif choice == "17" then
            if not confirmAction("Вы уверены, что хотите выйти?") then
                print("❌ Выход отменен")
                os.sleep(1)
            else
                running = false
                if craftThread then
                    craftThread:join()
                end
                if monitorThread then
                    monitoring = false
                    monitorThread:join()
                end
                print("👋 Выход...")
                break
            end
        end
    end
end

-- Основная инициализация
print("Загрузка умной системы автокрафта...")
initExternalStorage()  -- Инициализируем хранилище при запуске
loadMEKnowledge()
loadConfig()

if not meKnowledge.items or #meKnowledge.items == 0 then
    print("🔄 Первоначальный анализ ME системы...")
    analyzeMESystem()
end

print("✅ Умная система готова!")
print("📊 Автокрафтов: " .. tableLength(craftDB))
print("📚 Знаний ME: " .. (meKnowledge.items and #meKnowledge.items or 0) .. " предметов")
print("⏱️ Время крафта: " .. tableLength(meKnowledge.craftTimes or {}))
print("📋 История крафтов: " .. (meKnowledge.craftHistory and #meKnowledge.craftHistory or 0))
print("💾 Хранилище: " .. (STORAGE_CONFIG.useExternalStorage and "🟢 ВНЕШНЕЕ" or "🔴 ЛОКАЛЬНОЕ"))
os.sleep(2)

mainMenu()

