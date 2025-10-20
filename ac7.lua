local component = require("component")
local event = require("event")
local serialization = require("serialization")
local term = require("term")
local thread = require("thread")
local computer = require("computer")

-- ОБНОВЛЕННАЯ Конфигурация безопасности и оптимизации для БОЛЬШИХ объемов данных
local SAFETY_CONFIG = {
    -- Энергобезопасность
    minOperationInterval = 1.2,      -- Уменьшил паузу для большей производительности
    heavyOperationInterval = 2.5,    -- Оптимизированная пауза после тяжелых операций
    monitorInterval = 3.5,           -- Уменьшен интервал мониторинга
    
    -- ОПТИМИЗИРОВАННЫЕ лимиты для БОЛЬШИХ объемов данных
    maxItems = 5000,                 -- Увеличил для 1500+ предметов
    maxCraftables = 3000,            -- Увеличил для 1500+ крафтов
    maxHistory = 500,                -- Увеличил историю
    maxResearch = 2000,              -- Увеличил лимит исследований
    chunkSize = 100,                 -- Увеличил размер чанков для производительности
    saveInterval = 200,              -- Увеличил интервал сохранения
    sleepInterval = 0.02,            -- Уменьшил паузу для скорости
    
    -- Защита от перегрева
    maxContinuousOperations = 20,    -- Увеличил лимит операций
    cooldownTime = 1.5,              -- Уменьшил время остывания
    
    -- Стабильность системы
    operationTimeout = 180,          -- Увеличил таймаут для больших операций
    retryDelay = 6.0                 -- Уменьшил задержку между повторами
}

local STORAGE_CONFIG = {
    primaryStorage = "/home/",
    externalStorage = "/mnt/raid/",
    useExternalStorage = false
}

-- Глобальные счетчики для мониторинга
local systemStats = {
    operationsCount = 0,
    lastOperationTime = 0,
    energyWarnings = 0,
    memoryWarnings = 0
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

-- НОВАЯ ФУНКЦИЯ: Быстрая оптимизация данных для больших объемов
local function fastOptimizeDataForSave(data)
    local optimized = {
        items = data.items or {},
        craftables = data.craftables or {},
        cpus = data.cpus or {},
        patterns = data.patterns or {},
        craftTimes = data.craftTimes or {},
        craftHistory = {},
        researchDB = data.researchDB or {}
    }
    
    -- ОПТИМИЗИРОВАННАЯ обработка истории - сохраняем только последние записи
    if data.craftHistory then
        for i = math.max(1, #data.craftHistory - SAFETY_CONFIG.maxHistory + 1), #data.craftHistory do
            if data.craftHistory[i] then
                local obs = data.craftHistory[i]
                table.insert(optimized.craftHistory, {
                    cpuIndex = obs.cpuIndex,
                    duration = obs.duration or 0,
                    status = obs.status or "completed"
                })
            end
        end
    end
    
    return optimized
end

-- ОПТИМИЗИРОВАННАЯ функция оптимизации памяти для больших объемов
local function fastOptimizeMemory()
    -- Быстрая оптимизация истории крафтов
    if meKnowledge.craftHistory and #meKnowledge.craftHistory > SAFETY_CONFIG.maxHistory then
        local newHistory = {}
        for i = math.max(1, #meKnowledge.craftHistory - SAFETY_CONFIG.maxHistory + 1), #meKnowledge.craftHistory do
            table.insert(newHistory, meKnowledge.craftHistory[i])
        end
        meKnowledge.craftHistory = newHistory
    end
    
    -- Быстрая пауза после оптимизации
    os.sleep(SAFETY_CONFIG.minOperationInterval * 0.5)
end

-- ОПТИМИЗИРОВАННАЯ функция чанковой обработки для больших массивов
local function fastProcessInChunks(data, processCallback, itemName)
    local total = #data
    print("   📦 Всего " .. itemName .. ": " .. total)
    
    local result = {}
    local processed = 0
    
    for chunkStart = 1, total, SAFETY_CONFIG.chunkSize do
        if not systemSafetyCheck() then
            print("   ⚠️  Прервано по соображениям безопасности")
            break
        end
        
        local chunkEnd = math.min(chunkStart + SAFETY_CONFIG.chunkSize - 1, total)
        print("   Обработка чанка: " .. chunkStart .. "-" .. chunkEnd)
        
        for i = chunkStart, chunkEnd do
            local item = data[i]
            if item then
                local processedItem = processCallback(item, i)
                if processedItem then
                    table.insert(result, processedItem)
                end
            end
            
            processed = processed + 1
            
            -- ОПТИМИЗИРОВАННАЯ пауза для системы
            if processed % 50 == 0 then
                os.sleep(SAFETY_CONFIG.sleepInterval)
            end
        end
        
        -- ОПТИМИЗИРОВАННОЕ промежуточное сохранение
        if chunkEnd % SAFETY_CONFIG.saveInterval == 0 then
            fastOptimizeMemory()
            print("   💾 Промежуточное сохранение...")
            os.sleep(SAFETY_CONFIG.minOperationInterval * 0.7)
        end
    end
    
    print("   ✅ " .. itemName .. " обработано: " .. #result)
    return result
end

-- НОВАЯ ФУНКЦИЯ: Быстрый поиск в больших массивах
local function fastFindInArray(array, predicate)
    if not array then return nil end
    for i = 1, #array do
        if predicate(array[i], i) then
            return array[i], i
        end
        -- ОПТИМИЗАЦИЯ: Пауза каждые 100 элементов
        if i % 100 == 0 then
            os.sleep(SAFETY_CONFIG.sleepInterval)
        end
    end
    return nil
end

-- НОВАЯ ФУНКЦИЯ: Быстрое обновление счетчиков предметов
local function fastUpdateItemCounts()
    return safeOperation("fastUpdateItemCounts", function()
        local success, items = pcall(me.getItemsInNetwork)
        if success and items and meKnowledge.items then
            -- Используем быстрый поиск для обновления
            for i = 1, math.min(200, #items) do
                local item = items[i]
                if item and item.name then
                    local foundItem = fastFindInArray(meKnowledge.items, function(knownItem)
                        return knownItem.name == item.name
                    end)
                    if foundItem then
                        foundItem.size = item.size or 0
                    end
                end
                if i % 20 == 0 then
                    os.sleep(SAFETY_CONFIG.sleepInterval)
                end
            end
        end
    end)
end

-- ОСТАЛЬНЫЕ ФУНКЦИИ ОСТАЮТСЯ БЕЗ ИЗМЕНЕНИЙ, но используют оптимизированные версии:

local function confirmAction(message, warning)
    term.clear()
    if warning then
        print("⚠️  " .. warning)
        print()
    end
    print(message)
    print()
    print("1 - Да, продолжить")
    print("2 - Нет, отменить")
    print()
    print("Выберите действие:")
    
    local choice = io.read()
    return choice == "1"
end

local function dataManagement()
    while true do
        term.clear()
        print("=== 🗃️  УПРАВЛЕНИЕ ДАННЫМИ ===")
        print()
        print("1 - 🗑️  Очистить историю крафтов")
        print("2 - 🗑️  Очистить базу исследований") 
        print("3 - 🗑️  Очистить данные времени крафта")
        print("4 - 🗑️  Очистить ВСЕ данные (полный сброс)")
        print("5 - 📊 Статистика данных")
        print("6 - 🔙 Назад в меню")
        print()
        print("Выберите действие:")
        
        local choice = io.read()
        
        if choice == "1" then
            if confirmAction("Очистить всю историю крафтов?", "Это удалит все записи о прошлых крафтах!") then
                meKnowledge.craftHistory = {}
                if saveMEKnowledge() then
                    print("✅ История крафтов очищена!")
                else
                    print("❌ Ошибка сохранения")
                end
            else
                print("❌ Отменено")
            end
            os.sleep(2)
            
        elseif choice == "2" then
            if confirmAction("Очистить базу исследований?", "Это удалит все исследованные крафты!") then
                meKnowledge.researchDB = {}
                meKnowledge.patterns = {}
                if saveMEKnowledge() then
                    print("✅ База исследований очищена!")
                else
                    print("❌ Ошибка сохранения")
                end
            else
                print("❌ Отменено")
            end
            os.sleep(2)
            
        elseif choice == "3" then
            if confirmAction("Очистить данные времени крафта?", "Это удалит все измеренные времена крафтов!") then
                meKnowledge.craftTimes = {}
                if saveMEKnowledge() then
                    print("✅ Данные времени крафта очищены!")
                else
                    print("❌ Ошибка сохранения")
                end
            else
                print("❌ Отменено")
            end
            os.sleep(2)
            
        elseif choice == "4" then
            if confirmAction("ПОЛНЫЙ СБРОС всех данных?", "⚠️  ВНИМАНИЕ: Это удалит ВСЕ данные системы!") then
                if confirmAction("Точно сбросить ВСЕ данные?", "❌ ЭТО ДЕЙСТВИЕ НЕОБРАТИМО!") then
                    meKnowledge = {
                        items = {}, craftables = {}, cpus = {}, 
                        patterns = {}, craftTimes = {}, 
                        craftHistory = {}, researchDB = {}
                    }
                    craftDB = {}
                    if saveMEKnowledge() and saveConfig() then
                        print("✅ Все данные сброшены!")
                    else
                        print("❌ Ошибка сохранения")
                    end
                else
                    print("❌ Отменено")
                end
            else
                print("❌ Отменено")
            end
            os.sleep(2)
            
        elseif choice == "5" then
            term.clear()
            print("=== 📊 СТАТИСТИКА ДАННЫХ ===")
            print()
            print("📦 Предметы в памяти: " .. (#meKnowledge.items or 0))
            print("🛠️ Craftables: " .. (#meKnowledge.craftables or 0))
            print("⚡ ЦП: " .. (#meKnowledge.cpus or 0))
            print("🔗 Паттерны: " .. tableLength(meKnowledge.patterns or {}))
            print("⏱️ Время крафта: " .. tableLength(meKnowledge.craftTimes or {}))
            print("📋 История крафтов: " .. (#meKnowledge.craftHistory or 0))
            print("🔬 Исследования: " .. (#meKnowledge.researchDB or 0))
            print("🚀 Автокрафтов: " .. tableLength(craftDB))
            print()
            print("💾 Используется внешнее хранилище: " .. (STORAGE_CONFIG.useExternalStorage and "Да" or "Нет"))
            print()
            print("Нажмите Enter для продолжения...")
            io.read()
            
        elseif choice == "6" then
            break
        end
    end
end

local function systemSafetyCheck()
    local currentTime = computer.uptime()
    local timeSinceLastOp = currentTime - systemStats.lastOperationTime
    
    if timeSinceLastOp < SAFETY_CONFIG.minOperationInterval then
        local waitTime = SAFETY_CONFIG.minOperationInterval - timeSinceLastOp
        os.sleep(waitTime)
    end
    
    if systemStats.operationsCount >= SAFETY_CONFIG.maxContinuousOperations then
        os.sleep(SAFETY_CONFIG.cooldownTime)
        systemStats.operationsCount = 0
    end
    
    systemStats.operationsCount = systemStats.operationsCount + 1
    systemStats.lastOperationTime = computer.uptime()
    
    return true
end

local function safeOperation(operationName, operationFunc, ...)
    local startTime = computer.uptime()
    
    while computer.uptime() - startTime < SAFETY_CONFIG.operationTimeout do
        if not systemSafetyCheck() then
            return nil, "Системная проверка не пройдена"
        end
        
        local success, result = pcall(operationFunc, ...)
        
        if success then
            os.sleep(SAFETY_CONFIG.minOperationInterval)
            return result
        else
            print("⚠️  Ошибка в " .. operationName .. ": " .. tostring(result))
            print("🔄 Повтор через " .. SAFETY_CONFIG.retryDelay .. " сек...")
            os.sleep(SAFETY_CONFIG.retryDelay)
        end
    end
    
    return nil, "Таймаут операции: " .. operationName
end

local function heavyOperation(operationName, operationFunc, ...)
    local result = safeOperation(operationName, operationFunc, ...)
    os.sleep(SAFETY_CONFIG.heavyOperationInterval)
    return result
end

local function initExternalStorage()
    local mounts = {"/mnt/raid", "/mnt/external", "/mnt/disk", "/mnt"}
    for _, mount in ipairs(mounts) do
        local checkCmd = "test -d " .. mount .. " 2>/dev/null"
        if os.execute(checkCmd) then
            STORAGE_CONFIG.externalStorage = mount .. "/"
            STORAGE_CONFIG.useExternalStorage = true
            print("✅ Внешнее хранилище: " .. mount)
            return true
        end
    end
    
    os.execute("mkdir -p /mnt/raid 2>/dev/null")
    print("⚠️  Внешнее хранилище не найдено, используем основное")
    return false
end

local function getStoragePath(filename)
    if STORAGE_CONFIG.useExternalStorage then
        return STORAGE_CONFIG.externalStorage .. filename
    else
        return STORAGE_CONFIG.primaryStorage .. filename
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

local function loadMEKnowledge()
    return safeOperation("loadMEKnowledge", function()
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
                    print("   ЦП: " .. #meKnowledge.cpus)
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
    end)
end

local function saveMEKnowledge()
    return safeOperation("saveMEKnowledge", function()
        local optimizedData = fastOptimizeDataForSave(meKnowledge)
        
        local path = getStoragePath("me_knowledge.dat")
        local file = io.open(path, "w")
        if file then
            file:write(serialization.serialize(optimizedData))
            file:close()
            
            if STORAGE_CONFIG.useExternalStorage then
                local backupFile = io.open(STORAGE_CONFIG.primaryStorage .. "me_knowledge.dat", "w")
                if backupFile then
                    backupFile:write(serialization.serialize(optimizedData))
                    backupFile:close()
                end
            end
            
            return true
        end
        return false
    end)
end

local function loadConfig()
    return safeOperation("loadConfig", function()
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
    end)
end

local function saveConfig()
    return safeOperation("saveConfig", function()
        local file = io.open(configFile, "w")
        if file then
            file:write(serialization.serialize(craftDB))
            file:close()
            return true
        end
        return false
    end)
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

-- ОПТИМИЗИРОВАННАЯ функция анализа ME системы для больших объемов
local function analyzeMESystem()
    if not confirmAction("Запустить анализ ME системы?", "Это может занять несколько минут и создать нагрузку на систему!") then
        print("❌ Анализ отменен")
        return
    end
    
    print("🔍 Анализ ME системы...")
    initExternalStorage()
    fastOptimizeMemory()
    
    if not meKnowledge.items then meKnowledge.items = {} end
    if not meKnowledge.craftables then meKnowledge.craftables = {} end
    if not meKnowledge.cpus then meKnowledge.cpus = {} end
    if not meKnowledge.patterns then meKnowledge.patterns = {} end
    if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
    if not meKnowledge.craftHistory then meKnowledge.craftHistory = {} end
    
    -- Анализ предметов с ОПТИМИЗИРОВАННОЙ чанковой обработкой
    local success, items = safeOperation("getItemsInNetwork", me.getItemsInNetwork)
    if success and items then
        meKnowledge.items = fastProcessInChunks(items, function(item, index)
            if item and item.name then
                return {
                    name = item.name,
                    size = item.size or 0,
                    label = item.label or "нет"
                }
            end
            return nil
        end, "предметов")
    else
        print("   ❌ Ошибка анализа предметов")
    end
    
    os.sleep(SAFETY_CONFIG.heavyOperationInterval)
    
    -- ОПТИМИЗИРОВАННЫЙ анализ craftables
    print("   🛠️ Анализ craftables...")
    local success, craftables = safeOperation("getCraftables", me.getCraftables)
    if success and craftables then
        meKnowledge.craftables = fastProcessInChunks(craftables, function(craftable, index)
            if craftable then
                local craftableInfo = {
                    index = index,
                    methods = {},
                    fields = {}
                }
                
                if craftable.request then craftableInfo.methods.request = true end
                if craftable.getItemStack then craftableInfo.methods.getItemStack = true end
                
                if craftable.getItemStack then
                    local itemSuccess, itemStack = safeOperation("getItemStack", craftable.getItemStack)
                    if itemSuccess and itemStack then
                        craftableInfo.itemStack = {
                            name = itemStack.name or "unknown",
                            label = itemStack.label or "нет",
                            size = itemStack.size or 1
                        }
                        
                        if itemStack.name then
                            meKnowledge.patterns[itemStack.name] = index
                        end
                    end
                end
                
                return craftableInfo
            end
            return nil
        end, "craftables")
    else
        print("   ❌ Ошибка анализа craftables")
    end
    
    os.sleep(SAFETY_CONFIG.heavyOperationInterval)
    
    -- ОПТИМИЗИРОВАННЫЙ анализ ЦП
    print("   ⚡ Анализ ЦП...")
    local success, cpus = safeOperation("getCraftingCPUs", me.getCraftingCPUs)
    if success and cpus then
        meKnowledge.cpus = fastProcessInChunks(cpus, function(cpu, index)
            if cpu then
                return {
                    index = index,
                    busy = cpu.busy or false,
                    storage = cpu.storage or 0,
                    name = cpu.name or "Без названия"
                }
            end
            return nil
        end, "ЦП")
    else
        print("   ❌ Ошибка анализа ЦП")
    end
    
    if saveMEKnowledge() then
        print("✅ Анализ ME системы завершен!")
    else
        print("❌ Ошибка сохранения базы знаний")
    end
end

-- ОПТИМИЗИРОВАННАЯ функция исследования всех крафтов для больших объемов
local function researchAllCrafts()
    if not confirmAction("Запустить исследование всех крафтов?", "⚠️  ВНИМАНИЕ: Это запустит все доступные крафты в порядке очереди!") then
        print("❌ Исследование отменен")
        return
    end
    
    print("🔬 Интеллектуальное исследование всех крафтов...")
    
    local success, craftables = safeOperation("getCraftables", me.getCraftables)
    if not success or not craftables then
        print("❌ Не удалось получить список craftables")
        return
    end
    
    local result = fastProcessInChunks(craftables, function(craftable, index)
        if craftable and craftable.getItemStack then
            local itemSuccess, itemStack = safeOperation("getItemStack", craftable.getItemStack)
            if itemSuccess and itemStack and itemStack.name then
                local itemInfo = {
                    craftableIndex = index,
                    itemID = itemStack.name,
                    label = itemStack.label or "Без названия",
                    size = itemStack.size or 1
                }
                
                meKnowledge.patterns[itemStack.name] = index
                
                if #meKnowledge.researchDB % 100 == 0 then
                    print("   ✅ Исследовано: " .. #meKnowledge.researchDB .. " крафтов")
                    os.sleep(SAFETY_CONFIG.minOperationInterval)
                end
                
                return itemInfo
            end
        end
        return nil
    end, "крафтов для исследования")
    
    meKnowledge.researchDB = result
    
    if saveMEKnowledge() then
        print("✅ Исследование завершено! Найдено крафтов: " .. #result)
    else
        print("❌ Ошибка сохранения исследований")
    end
    return result
end

local function showResearchDB()
    if not meKnowledge.researchDB or #meKnowledge.researchDB == 0 then
        print("❌ База исследований пуста! Сначала выполните исследование.")
        os.sleep(2)
        return
    end
    
    local dataToShow = {}
    for i, research in ipairs(meKnowledge.researchDB) do
        if i <= 300 then
            table.insert(dataToShow, string.format("Craftable #%d: %s (ID: %s)", 
                research.craftableIndex, research.label, research.itemID))
        end
    end
    
    if #meKnowledge.researchDB > 300 then
        table.insert(dataToShow, "... и еще " .. (#meKnowledge.researchDB - 300) .. " записей")
    end
    
    showPaginated(dataToShow, "🔬 БАЗА ИССЛЕДОВАНИЙ КРАФТОВ", 15)
end

local function getItemCount(itemID)
    return safeOperation("getItemCount", function()
        if not meKnowledge.items then return 0 end
        local foundItem = fastFindInArray(meKnowledge.items, function(item)
            return item.name == itemID
        end)
        return foundItem and (foundItem.size or 0) or 0
    end)
end

local function getItemInfo(itemID)
    return safeOperation("getItemInfo", function()
        if not meKnowledge.items then return nil end
        return fastFindInArray(meKnowledge.items, function(item)
            return item.name == itemID
        end)
    end)
end

local function measureCraftTime(itemID, craftName, craftableIndex)
    print("⏱️ Измерение времени крафта для: " .. craftName)
    
    local success, craftables = safeOperation("getCraftables", me.getCraftables)
    if not success or not craftables or not craftables[craftableIndex] then
        print("❌ Craftable не найден для измерения времени")
        return nil
    end
    
    local craftable = craftables[craftableIndex]
    local totalTime = 0
    local successfulMeasurements = 0
    
    for attempt = 1, 2 do
        if not systemSafetyCheck() then
            print("   ⚠️  Прервано по соображениям безопасности")
            break
        end
        
        print("   Попытка " .. attempt .. "/2...")
        
        local startCount = getItemCount(itemID)
        local startTime = computer.uptime()
        
        local craftSuccess, result = safeOperation("craftable.request", craftable.request, 1)
        
        if craftSuccess and result then
            local timeout = 20
            local craftCompleted = false
            
            for i = 1, timeout do
                os.sleep(1.5)
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
                
                if i % 5 == 0 then
                    os.sleep(SAFETY_CONFIG.minOperationInterval)
                end
            end
            
            if not craftCompleted then
                print("     ❌ Таймаут измерения попытки " .. attempt)
            end
        else
            print("     ❌ Ошибка заказа крафта")
        end
        
        os.sleep(SAFETY_CONFIG.retryDelay) 
    end
    
    if successfulMeasurements > 0 then
        local averageTime = totalTime / successfulMeasurements
        meKnowledge.craftTimes[itemID] = averageTime
        if saveMEKnowledge() then
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
    local count = 0
    for itemID, time in pairs(meKnowledge.craftTimes) do
        if count < 150 then
            local label = itemID
            local itemInfo = getItemInfo(itemID)
            if itemInfo and itemInfo.label then
                label = itemInfo.label
            end
            
            table.insert(dataToShow, string.format("%s: %.1f сек", label, time))
            count = count + 1
        else
            break
        end
    end
    
    if tableLength(meKnowledge.craftTimes) > 150 then
        table.insert(dataToShow, "... и еще " .. (tableLength(meKnowledge.craftTimes) - 150) .. " записей")
    end
    
    showPaginated(dataToShow, "⏱️ БАЗА ВРЕМЕНИ КРАФТА", 15)
end

-- ОПТИМИЗИРОВАННЫЙ мониторинг крафтов для больших систем
local function monitorActiveCrafts()
    print("🎯 Запуск мониторинга активных крафтов...")
    
    local lastCpuState = {}
    local currentObservations = {}
    
    if meKnowledge.cpus then
        for i, cpu in ipairs(meKnowledge.cpus) do
            lastCpuState[i] = {busy = cpu.busy or false, name = cpu.name or "Без названия"}
        end
    end
    
    local monitoringCycle = 0
    
    while monitoring do
        monitoringCycle = monitoringCycle + 1
        
        if monitoringCycle % 20 == 0 then
            fastOptimizeMemory()
        end
        
        if monitoringCycle % 8 == 0 then
            if not systemSafetyCheck() then
                os.sleep(SAFETY_CONFIG.retryDelay)
                systemStats.operationsCount = 0
            end
        end
        
        local success, cpus = safeOperation("getCraftingCPUs", me.getCraftingCPUs)
        if success and cpus then
            for i, cpu in ipairs(cpus) do
                if cpu then
                    local currentBusy = cpu.busy or false
                    local lastBusy = lastCpuState[i] and lastCpuState[i].busy or false
                    
                    if currentBusy and not lastBusy then
                        print("🔍 Обнаружен новый крафт на ЦП #" .. i)
                        
                        local observation = {
                            cpuIndex = i,
                            cpuName = cpu.name or "Без названия",
                            startTime = computer.uptime(),
                            startItems = {},
                            status = "active"
                        }
                        
                        if meKnowledge.items then
                            for j = 1, math.min(100, #meKnowledge.items) do
                                local item = meKnowledge.items[j]
                                if item then
                                    observation.startItems[item.name] = item.size or 0
                                end
                            end
                        end
                        
                        currentObservations[i] = observation
                        
                    elseif not currentBusy and lastBusy and currentObservations[i] then
                        local observation = currentObservations[i]
                        observation.endTime = computer.uptime()
                        observation.duration = observation.endTime - observation.startTime
                        observation.status = "completed"
                        
                        local craftedItems = {}
                        if meKnowledge.items then
                            for j = 1, math.min(100, #meKnowledge.items) do
                                local item = meKnowledge.items[j]
                                if item then
                                    local startCount = observation.startItems[item.name] or 0
                                    local endCount = item.size or 0
                                    if endCount > startCount then
                                        table.insert(craftedItems, {
                                            itemID = item.name,
                                            itemLabel = item.label or item.name,
                                            amount = endCount - startCount
                                        })
                                    end
                                end
                            end
                        end
                        
                        observation.craftedItems = craftedItems
                        
                        if not meKnowledge.craftHistory then
                            meKnowledge.craftHistory = {}
                        end
                        table.insert(meKnowledge.craftHistory, observation)
                        
                        if #craftedItems > 0 then
                            local mainItem = craftedItems[1]
                            meKnowledge.craftTimes[mainItem.itemID] = observation.duration
                        end
                        
                        if #meKnowledge.craftHistory <= SAFETY_CONFIG.maxHistory * 2 then
                            saveMEKnowledge()
                        end
                        
                        print("✅ Завершен крафт на ЦП #" .. i .. ", длительность: " .. string.format("%.1f", observation.duration) .. " сек")
                        currentObservations[i] = nil
                    end
                    
                    lastCpuState[i] = {busy = currentBusy, name = cpu.name or "Без названия"}
                end
            end
        end
        
        os.sleep(SAFETY_CONFIG.monitorInterval)
    end
end

local function toggleCraftMonitoring()
    if monitoring then
        monitoring = false
        if monitorThread then
            monitorThread:join()
            monitorThread = nil
        end
        print("🛑 Мониторинг крафтов остановлен")
    else
        if confirmAction("Запустить мониторинг крафтов?", "Система будет отслеживать все активные крафты в реальном времени") then
            monitoring = true
            monitorThread = thread.create(monitorActiveCrafts)
            print("🎯 Мониторинг крафтов запущен")
        else
            print("❌ Мониторинг отменен")
        end
    end
    os.sleep(SAFETY_CONFIG.minOperationInterval * 2)
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
    local success, cpus = safeOperation("getCraftingCPUs", me.getCraftingCPUs)
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
        for i = #meKnowledge.craftHistory, math.max(1, #meKnowledge.craftHistory - 2), -1 do
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

-- ОПТИМИЗИРОВАННЫЙ умный поиск craftable для больших объемов
local function findCraftableSmart(itemID, itemName)
    print("🔍 Умный поиск craftable для: " .. itemName)
    
    if meKnowledge.patterns and meKnowledge.patterns[itemID] then
        local craftableIndex = meKnowledge.patterns[itemID]
        print("   ✅ Найден в паттернах: craftable #" .. craftableIndex)
        return craftableIndex
    end
    
    if meKnowledge.craftables then
        for i, craftableInfo in ipairs(meKnowledge.craftables) do
            if i > 400 then break end
            if craftableInfo.itemStack and craftableInfo.itemStack.name == itemID then
                print("   ✅ Найден через itemStack: craftable #" .. i)
                meKnowledge.patterns[itemID] = i
                saveMEKnowledge()
                return i
            end
            if i % 40 == 0 then
                os.sleep(SAFETY_CONFIG.sleepInterval)
            end
        end
    end
    
    if meKnowledge.craftables then
        for i, craftableInfo in ipairs(meKnowledge.craftables) do
            if i > 400 then break end
            if craftableInfo.itemStack then
                local stack = craftableInfo.itemStack
                if stack.label and stack.label:lower():find(itemName:lower(), 1, true) then
                    print("   ✅ Найден по совпадению label: craftable #" .. i)
                    meKnowledge.patterns[itemID] = i
                    saveMEKnowledge()
                    return i
                end
            end
            if i % 40 == 0 then
                os.sleep(SAFETY_CONFIG.sleepInterval)
            end
        end
    end
    
    print("   ❌ Craftable не найден в базе знаний")
    return nil
end

local function requestCraft(itemID, amount, cpuIndex, craftName)
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
    
    local success, craftables = safeOperation("getCraftables", me.getCraftables)
    if not success or not craftables or not craftables[craftableIndex] then
        print("❌ Craftable не найден: #" .. craftableIndex)
        return false
    end
    
    local craftable = craftables[craftableIndex]
    local craftSuccess, result = safeOperation("craftable.request", craftable.request, amount)
    
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
    local timeout = averageTime and (averageTime * 3 + 90) or 450
    local startTime = computer.uptime()
    
    if averageTime then
        print("   📊 Ожидаемое время: ~" .. string.format("%.1f", averageTime) .. " сек")
    end
    
    local checkCount = 0
    
    while computer.uptime() - startTime < timeout do
        if not systemSafetyCheck() then
            os.sleep(SAFETY_CONFIG.retryDelay)
            systemStats.operationsCount = 0
        end
        
        fastUpdateItemCounts()
        local currentCount = getItemCount(itemID)
        local elapsed = math.floor(computer.uptime() - startTime)
        print("   Прогресс: " .. currentCount .. "/" .. targetAmount .. " (" .. elapsed .. "с)")
        
        if currentCount >= targetAmount then
            print("✅ Крафт завершен! " .. craftName)
            
            if not meKnowledge.craftTimes or not meKnowledge.craftTimes[itemID] then
                local actualTime = computer.uptime() - startTime
                if not meKnowledge.craftTimes then meKnowledge.craftTimes = {} end
                meKnowledge.craftTimes[itemID] = actualTime
                saveMEKnowledge()
                print("   💾 Сохранено время крафта: " .. string.format("%.1f", actualTime) .. " сек")
            end
            
            return true
        end
        
        checkCount = checkCount + 1
        if checkCount % 3 == 0 then
            os.sleep(SAFETY_CONFIG.minOperationInterval * 2)
        end
        
        os.sleep(8)
    end
    
    print("❌ Таймаут ожидания крафта!")
    return false
end

-- ОПТИМИЗИРОВАННЫЙ цикл крафта для больших систем
local function craftLoop()
    print("🚀 Запуск умного автокрафта...")
    
    local cycleCount = 0
    
    while running do
        cycleCount = cycleCount + 1
        
        if cycleCount % 8 == 0 then
            systemStats.operationsCount = 0
            fastOptimizeMemory()
        end
        
        for name, craftData in pairs(craftDB) do
            if not running then break end
            
            if not systemSafetyCheck() then
                os.sleep(SAFETY_CONFIG.retryDelay)
                systemStats.operationsCount = 0
            end
            
            print("\n🔍 Проверка: " .. name)
            fastUpdateItemCounts()
            local currentCount = getItemCount(craftData.itemID)
            print("📦 Количество: " .. currentCount .. "/" .. craftData.targetAmount)
            
            if currentCount < craftData.targetAmount then
                local needed = craftData.targetAmount - currentCount
                print("🛠️ Необходимо крафтить: " .. needed .. " шт.")
                
                if requestCraft(craftData.itemID, needed, craftData.cpuIndex, name) then
                    waitForCraft(craftData.itemID, craftData.targetAmount, name)
                else
                    print("❌ Не удалось заказать крафт")
                end
            else
                print("✅ Достаточное количество")
            end
            
            local extendedTimeout = craftData.checkTimeout + 10
            print("⏰ Ожидание " .. extendedTimeout .. " сек...")
            os.sleep(extendedTimeout)
        end
        
        if running then
            print("\n--- 🔄 Цикл завершен, перерыв " .. SAFETY_CONFIG.cooldownTime * 2 .. " сек ---")
            os.sleep(SAFETY_CONFIG.cooldownTime * 2)
        end
    end
end

local function showMEKnowledge()
    term.clear()
    print("=== 📚 БАЗА ЗНАНИЙ ME СИСТЕМЫ ===")
    
    print("\n📦 ПРЕДМЕТЫ В СИСТЕМЕ (" .. (meKnowledge.items and #meKnowledge.items or 0) .. "):")
    local itemsToShow = {}
    if meKnowledge.items then
        for i = 1, math.min(250, #meKnowledge.items) do
            table.insert(itemsToShow, meKnowledge.items[i])
        end
    end
    if #meKnowledge.items > 250 then
        table.insert(itemsToShow, {name = "...", size = 0, label = "и еще " .. (#meKnowledge.items - 250) .. " предметов"})
    end
    showPaginated(itemsToShow, "📦 ПРЕДМЕТЫ В СИСТЕМЕ", 15)
    
    print("\n🛠️ CRAFTABLES (" .. (meKnowledge.craftables and #meKnowledge.craftables or 0) .. "):")
    local craftablesToShow = {}
    if meKnowledge.craftables then
        for i = 1, math.min(250, #meKnowledge.craftables) do
            table.insert(craftablesToShow, meKnowledge.craftables[i])
        end
    end
    if #meKnowledge.craftables > 250 then
        table.insert(craftablesToShow, {itemStack = {name = "...", label = "и еще " .. (#meKnowledge.craftables - 250) .. " craftables"}})
    end
    showPaginated(craftablesToShow, "🛠️ CRAFTABLES", 15)
    
    print("\n🔗 ВЫЯВЛЕННЫЕ ПАТТЕРНЫ:")
    local patternsList = {}
    local patternCount = 0
    if meKnowledge.patterns then
        for itemID, craftableIndex in pairs(meKnowledge.patterns) do
            if patternCount < 150 then
                table.insert(patternsList, "  " .. itemID .. " -> craftable #" .. craftableIndex)
                patternCount = patternCount + 1
            else
                break
            end
        end
    end
    if tableLength(meKnowledge.patterns) > 150 then
        table.insert(patternsList, "  ... и еще " .. (tableLength(meKnowledge.patterns) - 150) .. " паттернов")
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
    local maxDisplay = 30
    
    for i = 1, math.min(maxDisplay, #meKnowledge.craftables) do
        local craftable = meKnowledge.craftables[i]
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
            local fieldCount = 0
            for key, value in pairs(craftable.fields) do
                if fieldCount < 5 then
                    craftableText = craftableText .. "    " .. key .. ": " .. tostring(value) .. "\n"
                    fieldCount = fieldCount + 1
                else
                    craftableText = craftableText .. "    ... и другие поля\n"
                    break
                end
            end
        end
        
        table.insert(dataToShow, craftableText)
    end
    
    if #meKnowledge.craftables > maxDisplay then
        table.insert(dataToShow, "\n... и еще " .. (#meKnowledge.craftables - maxDisplay) .. " craftables")
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
    end
end

local function addAutoCraft()
    term.clear()
    print("=== ➕ ДОБАВЛЕНИЕ АВТОКРАФТА ===")
    
    showAvailableCPUs()
    print()
    
    print("📦 ПОСЛЕДНИЕ 20 ПРЕДМЕТОВ В СИСТЕМЕ:")
    local recentItems = {}
    if meKnowledge.items and #meKnowledge.items > 0 then
        local startIndex = math.max(1, #meKnowledge.items - 19)
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
        local foundItem = fastFindInArray(meKnowledge.items, function(item)
            return item.name == itemID
        end)
        if foundItem then
            itemExists = true
            itemLabel = foundItem.label or itemID
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
    
    print("Введите №ЦП для обработки (1-" .. (meKnowledge.cpus and #meKnowledge.cpus or 0) .. "):")
    local cpuIndex = tonumber(io.read())
    
    local maxCPUs = meKnowledge.cpus and #meKnowledge.cpus or 0
    if not cpuIndex or cpuIndex < 1 or cpuIndex > maxCPUs then
        print("Ошибка: неверный номер ЦП! Доступны: 1-" .. maxCPUs)
        os.sleep(2)
        return
    end
    
    print("Введите таймаут проверки (в секундах, минимум 10):")
    local timeout = tonumber(io.read())
    
    if not timeout or timeout < 10 then
        timeout = 10
        print("Таймаут установлен на минимум 10 секунд")
    end
    
    local craftableIndex = findCraftableSmart(itemID, craftName)
    
    craftDB[craftName] = {
        itemID = itemID,
        targetAmount = targetAmount,
        cpuIndex = cpuIndex,
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
        
        local craftTime = meKnowledge.craftTimes and meKnowledge.craftTimes[data.itemID]
        local timeInfo = craftTime and string.format("Время крафта: %.1f сек", craftTime) or "Время крафта: не измерено"
        
        local entry = string.format("%s %s: %d/%d\n  ID: %s\n  ЦП: #%d\n  Таймаут: %d сек\n  %s\n  %s\n---",
            status, name, current, data.targetAmount, data.itemID, data.cpuIndex, 
            data.checkTimeout, craftableInfo, timeInfo)
        
        table.insert(dataToShow, entry)
    end
    
    showPaginated(dataToShow, "📊 БАЗА АВТОКРАФТОВ", 5)
end

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
        print("16 - 🗃️  Управление данными")
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
            running = false
            craftThread:join()
            craftThread = nil
            running = true
            print("✅ Автокрафт остановлен!")
            os.sleep(1)
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
            if confirmAction("Обновить данные ME системы?", "Это перезапишет текущие данные!") then
                analyzeMESystem()
                print("✅ Данные обновлены!")
            else
                print("❌ Отменено")
            end
            os.sleep(2)
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
            fastOptimizeMemory()
            print("✅ Память оптимизирована!")
            os.sleep(1)
        elseif choice == "16" then
            dataManagement()
        elseif choice == "17" then
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
        
        os.sleep(SAFETY_CONFIG.minOperationInterval)
    end
end

print("Загрузка умной системы автокрафта...")
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
os.sleep(2)

mainMenu()